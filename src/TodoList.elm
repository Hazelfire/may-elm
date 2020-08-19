port module TodoList exposing
    ( FolderEditing(..)
    , Model
    , Msg(..)
    , SyncStatus(..)
    , TaskEditing(..)
    , ViewId(..)
    , ViewType(..)
    , init
    , main
    , update
    )

{-| Main module. Contains main method for the application
-}

import Browser
import Date
import Html exposing (Attribute, Html, a, button, div, h3, i, input, label, li, nav, p, span, text, ul)
import Html.Attributes exposing (checked, class, href, id, type_, value)
import Html.Events exposing (keyCode, on, onBlur, onClick, onInput)
import Http
import Iso8601
import Json.Decode as D
import Json.Encode as E
import May.Auth as Auth
import May.FileSystem as FileSystem exposing (FileSystem)
import May.Folder as Folder exposing (Folder)
import May.Id as Id exposing (Id)
import May.Statistics as Statistics
import May.SyncList as SyncList exposing (SyncList)
import May.Task as Task exposing (Task)
import Random
import Task
import Time


type alias Model =
    { fs : FileSystem
    , viewing : ViewType
    , currentTime : Maybe Time.Posix
    , authState : Auth.AuthState
    , syncStatus : SyncStatus
    , notice : Notice
    }


type Notice
    = NoNotice
    | AskForSubscription
    | AskConfirmDeleteAccount


type SyncStatus
    = SyncOffline
    | Synced
    | Retreiving
    | RetreiveFailed
    | Updating
    | UpdateFailed


type ViewId
    = ViewIdFolder (Id Folder)
    | ViewIdTask (Id Task)


type ViewType
    = ViewTypeFolder FolderView
    | ViewTypeTask TaskView


type alias TaskView =
    { id : Id Task
    , editing : TaskEditing
    }


type TaskEditing
    = NotEditingTask
    | EditingTaskName String
    | EditingTaskDuration String
    | ConfirmingDeleteTask


type alias FolderView =
    { id : Id Folder
    , editing : FolderEditing
    }


type FolderEditing
    = NotEditingFolder
    | EditingFolderName String
    | ConfirmingDeleteFolder


newFolderView : Id Folder -> ViewType
newFolderView id =
    ViewTypeFolder { id = id, editing = NotEditingFolder }


newTaskView : Id Task -> ViewType
newTaskView id =
    ViewTypeTask { id = id, editing = NotEditingTask }


type Msg
    = CreateFolder (Id Folder)
    | GotAuthResponse (Result String Auth.AuthTokens)
    | GotSubscriptionSessionId (Result Http.Error String)
    | GotNodes (Result Http.Error FileSystem.FSUpdate)
    | GotUpdateSuccess (Result Http.Error ())
    | NewFolder (Id Folder) (Id Folder)
    | CreateTask (Id Folder)
    | NewTask (Id Folder) (Id Task)
    | StartEditingTaskName String
    | RequestSubscription
    | StartEditingFolderName String
    | StartEditingTaskDuration
    | ChangeFolderName String
    | ChangeTaskName String
    | ChangeTaskDuration String
    | SetFolderName (Id Folder) String
    | SetTaskName (Id Task) String
    | SetTaskDuration (Id Task) Float
    | SetTaskDueNow (Id Task)
    | SetTaskDue (Id Task) (Maybe Time.Posix)
    | SetView ViewId
    | SetTime Time.Posix
    | ConfirmDeleteFolder
    | CloseConfirmDeleteFolder
    | DeleteFolder (Id Folder)
    | ConfirmDeleteTask
    | CloseConfirmDeleteTask
    | DeleteTask (Id Task)
    | Logout
    | ConfirmDeleteAccount
    | CancelConfirmDeleteAccount
    | DeleteAccount
    | GotDeleteAccount (Result Http.Error ())
    | NoOp


main : Program E.Value Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = \_ -> Time.every 5000.0 SetTime
        , view = view
        }


type alias Flags =
    { authCode : Maybe String
    , authTokens : Maybe Auth.AuthTokens
    , fs : FileSystem
    }


flagDecoder : D.Decoder Flags
flagDecoder =
    D.map3 Flags
        (D.maybe (D.field "code" D.string))
        (D.maybe (D.field "tokens" Auth.tokensDecoder))
        (D.field "fs" FileSystem.decode)


encodeFlags : Flags -> E.Value
encodeFlags flags =
    case flags.authTokens of
        Just tokens ->
            E.object [ ( "tokens", Auth.encodeTokens tokens ), ( "fs", FileSystem.encode flags.fs ) ]

        Nothing ->
            E.object [ ( "fs", FileSystem.encode flags.fs ) ]


{-| Initialises from storage modal
-}
init : E.Value -> ( Model, Cmd Msg )
init flagsValue =
    case D.decodeValue flagDecoder flagsValue of
        Ok flags ->
            let
                authState =
                    case ( flags.authCode, flags.authTokens ) of
                        ( Just _, _ ) ->
                            Auth.Authenticating

                        ( _, Just tokens ) ->
                            Auth.CheckingSubscription tokens

                        _ ->
                            Auth.Unauthenticated

                initModel =
                    { fs = flags.fs
                    , viewing = ViewTypeFolder { id = FileSystem.getRootId flags.fs, editing = NotEditingFolder }
                    , currentTime = Nothing
                    , authState = authState
                    , syncStatus = SyncOffline
                    , notice = NoNotice
                    }
            in
            case ( flags.authCode, flags.authTokens ) of
                ( Just code, _ ) ->
                    ( initModel, Cmd.batch [ Time.now |> Task.perform SetTime, Auth.exchangeAuthCode GotAuthResponse code ] )

                ( _, Just tokens ) ->
                    ( initModel, Cmd.batch [ Time.now |> Task.perform SetTime, checkSubscription tokens ] )

                _ ->
                    ( initModel, Time.now |> Task.perform SetTime )

        Err _ ->
            let
                rootId =
                    Id.rootId

                ( model, command ) =
                    saveToLocalStorage
                        { fs = FileSystem.new (Folder.new rootId "My Tasks")
                        , viewing = ViewTypeFolder { id = rootId, editing = NotEditingFolder }
                        , currentTime = Nothing
                        , authState = Auth.Unauthenticated
                        , syncStatus = SyncOffline
                        , notice = NoNotice
                        }
            in
            ( model, Cmd.batch [ command, Time.now |> Task.perform SetTime ] )


pure : a -> ( a, Cmd msg )
pure model =
    ( model, Cmd.none )


port setLocalStorage : E.Value -> Cmd msg


port setFocus : String -> Cmd msg


port openStripe : String -> Cmd msg


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        CreateFolder parentId ->
            ( model, Random.generate (NewFolder parentId) Id.generate )

        NewFolder parentId id ->
            saveToLocalStorageAndUpdate <| { model | fs = FileSystem.addFolder parentId (Folder.new id "New Folder") model.fs }

        CreateTask parentId ->
            ( model, Random.generate (NewTask parentId) Id.generate )

        NewTask parentId taskId ->
            saveToLocalStorageAndUpdate <| { model | fs = FileSystem.addTask parentId (Task.new taskId "New Task") model.fs }

        SetTime time ->
            let
                newModel =
                    { model | currentTime = Just time }
            in
            case Auth.stateAuthTokens model.authState of
                Just tokens ->
                    if Auth.authTokenNeedsRefresh time tokens then
                        ( { newModel | authState = Auth.Authenticating }, Auth.refreshTokens GotAuthResponse tokens )

                    else
                        pure newModel

                Nothing ->
                    pure newModel

        SetView vid ->
            case vid of
                ViewIdFolder fid ->
                    pure <| { model | viewing = newFolderView fid }

                ViewIdTask tid ->
                    pure <| { model | viewing = newTaskView tid }

        StartEditingFolderName name ->
            withCommand (always (setFocus "foldername")) <| mapViewing (mapFolderView (mapFolderEditing (always (EditingFolderName name)))) model

        StartEditingTaskName name ->
            withCommand (always (setFocus "taskname")) <| mapViewing (mapTaskView (mapTaskEditing (always (EditingTaskName name)))) model

        SetFolderName fid name ->
            let
                fsChange =
                    mapFileSystem (FileSystem.mapOnFolder fid (Folder.rename name)) model
            in
            saveToLocalStorageAndUpdate <| mapViewing (mapFolderView (mapFolderEditing (always NotEditingFolder))) fsChange

        SetTaskName tid name ->
            let
                fsChange =
                    mapFileSystem (FileSystem.mapOnTask tid (Task.rename name)) model
            in
            saveToLocalStorageAndUpdate <| mapViewing (mapTaskView (mapTaskEditing (always NotEditingTask))) fsChange

        StartEditingTaskDuration ->
            withCommand (always (setFocus "taskduration")) <| mapViewing (mapTaskView (mapTaskEditing (always (EditingTaskDuration "")))) model

        ChangeTaskName newName ->
            pure <| mapViewing (mapTaskView (mapTaskEditing (always (EditingTaskName newName)))) model

        ChangeTaskDuration newDuration ->
            pure <| mapViewing (mapTaskView (mapTaskEditing (always (EditingTaskDuration newDuration)))) model

        ChangeFolderName newName ->
            pure <| mapViewing (mapFolderView (\x -> { x | editing = EditingFolderName newName })) model

        SetTaskDuration tid duration ->
            let
                fsChange =
                    mapFileSystem (FileSystem.mapOnTask tid (Task.setDuration duration)) model
            in
            saveToLocalStorageAndUpdate <| mapViewing (mapTaskView (mapTaskEditing (always NotEditingTask))) fsChange

        SetTaskDue tid due ->
            saveToLocalStorageAndUpdate <| mapFileSystem (FileSystem.mapOnTask tid (Task.setDue due)) model

        SetTaskDueNow tid ->
            ( model, Time.now |> Task.perform (addWeek >> Just >> SetTaskDue tid) )

        ConfirmDeleteTask ->
            pure <| mapViewing (mapTaskView (mapTaskEditing (always ConfirmingDeleteTask))) model

        CloseConfirmDeleteTask ->
            pure <| mapViewing (mapTaskView (mapTaskEditing (always NotEditingTask))) model

        ConfirmDeleteFolder ->
            pure <| mapViewing (mapFolderView (mapFolderEditing (always ConfirmingDeleteFolder))) model

        CloseConfirmDeleteFolder ->
            pure <| mapViewing (mapFolderView (mapFolderEditing (always NotEditingFolder))) model

        DeleteFolder fid ->
            let
                parentId =
                    FileSystem.folderParent fid model.fs
            in
            case parentId of
                Just pid ->
                    let
                        fsChange =
                            mapFileSystem (FileSystem.deleteFolder fid) model
                    in
                    saveToLocalStorageAndUpdate <| mapViewing (always (newFolderView pid)) fsChange

                _ ->
                    pure model

        DeleteTask tid ->
            let
                parentId =
                    FileSystem.taskParent tid model.fs
            in
            case parentId of
                Just pid ->
                    let
                        fsChange =
                            mapFileSystem (FileSystem.deleteTask tid) model
                    in
                    saveToLocalStorageAndUpdate <| mapViewing (always (newFolderView pid)) fsChange

                _ ->
                    pure model

        GotAuthResponse (Err _) ->
            pure <| { model | authState = Auth.AuthFailed }

        GotAuthResponse (Ok response) ->
            let
                ( newModel, command ) =
                    saveToLocalStorage { model | authState = Auth.CheckingSubscription response }
            in
            ( newModel, Cmd.batch [ command, checkSubscription response ] )

        GotSubscriptionCheck (Err _) ->
            pure <| { model | authState = Auth.AuthFailed }

        GotSubscriptionCheck (Ok False) ->
            case Auth.stateAuthTokens model.authState of
                Just authResponse ->
                    pure <| { model | authState = Auth.SubscriptionNeeded authResponse, notice = AskForSubscription }

                _ ->
                    pure model

        GotSubscriptionCheck (Ok True) ->
            case Auth.stateAuthTokens model.authState of
                Just authResponse ->
                    ( { model | authState = Auth.Authenticated authResponse, syncStatus = Retreiving }, requestNodes authResponse )

                _ ->
                    pure model

        RequestSubscription ->
            case Auth.stateAuthTokens model.authState of
                Just authResponse ->
                    ( model, requestSubscription authResponse )

                _ ->
                    pure model

        GotSubscriptionSessionId (Ok sessionId) ->
            ( model, openStripe sessionId )

        GotSubscriptionSessionId (Err _) ->
            pure <| { model | authState = Auth.AuthFailed }

        GotNodes (Ok fsUpdate) ->
            case Auth.stateAuthTokens model.authState of
                Just authResponse ->
                    let
                        ( newModel, command ) =
                            saveToLocalStorage { model | fs = FileSystem.updateFS fsUpdate model.fs, syncStatus = Updating }
                    in
                    ( newModel, Cmd.batch [ command, sendSyncList authResponse (FileSystem.syncList model.fs) ] )

                _ ->
                    pure model

        GotNodes (Err _) ->
            pure <| { model | syncStatus = RetreiveFailed }

        GotUpdateSuccess (Err _) ->
            pure <| { model | syncStatus = UpdateFailed }

        GotUpdateSuccess (Ok _) ->
            pure <| { model | syncStatus = Synced, fs = FileSystem.emptySyncList model.fs }

        Logout ->
            saveToLocalStorage <| { model | syncStatus = SyncOffline, authState = Auth.Unauthenticated }

        ConfirmDeleteAccount ->
            pure <| { model | notice = AskConfirmDeleteAccount }

        CancelConfirmDeleteAccount ->
            pure <| { model | notice = NoNotice }

        DeleteAccount ->
            case Auth.stateAuthTokens model.authState of
                Just tokens ->
                    ( model, Auth.deleteUser GotDeleteAccount tokens )

                Nothing ->
                    pure model

        GotDeleteAccount (Err _) ->
            case Auth.stateAuthTokens model.authState of
                Just tokens ->
                    pure { model | authState = Auth.DeleteUserFailed tokens }

                Nothing ->
                    pure model

        GotDeleteAccount (Ok _) ->
            saveToLocalStorage <|
                { model
                    | authState = Auth.Unauthenticated
                    , syncStatus = SyncOffline
                    , fs = FileSystem.syncListAll model.fs
                    , notice = NoNotice
                }

        NoOp ->
            pure model


backendBase : String
backendBase =
    "https://api.may.hazelfire.net"


sendSyncList : Auth.AuthTokens -> SyncList -> Cmd Msg
sendSyncList tokens synclist =
    Http.request
        { url = backendBase ++ "/nodes"
        , method = "PATCH"
        , body = Http.stringBody "application/json" (E.encode 0 (SyncList.encode synclist))
        , headers = [ Auth.authHeader tokens ]
        , timeout = Nothing
        , tracker = Nothing
        , expect = Http.expectWhatever GotUpdateSuccess
        }


requestNodes : Auth.AuthTokens -> Cmd Msg
requestNodes tokens =
    Http.request
        { url = backendBase ++ "/nodes"
        , method = "GET"
        , body = Http.emptyBody
        , headers = [ Auth.authHeader tokens ]
        , timeout = Nothing
        , tracker = Nothing
        , expect = Http.expectJson GotNodes FileSystem.fsUpdateDecoder
        }


requestSubscription : Auth.AuthTokens -> Cmd Msg
requestSubscription tokens =
    Http.request
        { url = backendBase ++ "/subscription_session"
        , method = "GET"
        , body = Http.emptyBody
        , headers = [ Auth.authHeader tokens ]
        , timeout = Nothing
        , tracker = Nothing
        , expect = Http.expectJson GotSubscriptionSessionId D.string
        }


checkSubscription : Auth.AuthTokens -> Cmd Msg
checkSubscription tokens =
    let
        email =
            Auth.email tokens

        name =
            Auth.name tokens
    in
    Http.request
        { url = backendBase ++ "/subscription"
        , method = "POST"
        , body = Http.stringBody "application/json" (E.encode 0 (E.object [ ( "name", E.string name ), ( "email", E.string email ) ]))
        , headers = [ Auth.authHeader tokens ]
        , timeout = Nothing
        , tracker = Nothing
        , expect = Http.expectJson GotSubscriptionCheck D.bool
        }


saveToLocalStorage : Model -> ( Model, Cmd msg )
saveToLocalStorage =
    withCommand (\model -> setLocalStorage (encodeFlags (Flags Nothing (Auth.stateAuthTokens model.authState) model.fs)))


saveToLocalStorageAndUpdate : Model -> ( Model, Cmd Msg )
saveToLocalStorageAndUpdate model =
    case Auth.stateAuthTokens model.authState of
        Just tokens ->
            let
                sendSyncLists =
                    sendSyncList tokens (FileSystem.syncList model.fs)

                ( newModel, command ) =
                    saveToLocalStorage model
            in
            ( { newModel | syncStatus = Updating }, Cmd.batch [ command, sendSyncLists ] )

        Nothing ->
            saveToLocalStorage model


withCommand : (a -> Cmd msg) -> a -> ( a, Cmd msg )
withCommand commandFunc model =
    ( model, commandFunc model )


addWeek : Time.Posix -> Time.Posix
addWeek time =
    Time.millisToPosix <| Time.posixToMillis time + (1000 * 60 * 60 * 24 * 7)


mapViewing : (ViewType -> ViewType) -> Model -> Model
mapViewing func model =
    { model | viewing = func model.viewing }


mapTaskEditing : (TaskEditing -> TaskEditing) -> TaskView -> TaskView
mapTaskEditing func model =
    { model | editing = func model.editing }


mapFolderEditing : (FolderEditing -> FolderEditing) -> FolderView -> FolderView
mapFolderEditing func model =
    { model | editing = func model.editing }


mapFileSystem : (FileSystem -> FileSystem) -> Model -> Model
mapFileSystem func model =
    { model | fs = func model.fs }


mapTaskView : (TaskView -> TaskView) -> ViewType -> ViewType
mapTaskView func model =
    case model of
        ViewTypeTask taskView ->
            ViewTypeTask <| func taskView

        a ->
            a


mapFolderView : (FolderView -> FolderView) -> ViewType -> ViewType
mapFolderView func model =
    case model of
        ViewTypeFolder folderView ->
            ViewTypeFolder <| func folderView

        a ->
            a


view : Model -> Html Msg
view model =
    let
        now =
            case model.currentTime of
                Just time ->
                    time

                -- This should never really appear to the user, as this is only nothing in the instant the app is not loaded
                Nothing ->
                    Time.millisToPosix 0

        itemView =
            case model.viewing of
                ViewTypeFolder folderView ->
                    viewFolderDetails now folderView model.fs

                ViewTypeTask taskView ->
                    viewTaskDetails taskView model.fs
    in
    div []
        [ viewHeader model
        , case model.notice of
            NoNotice ->
                div [ class "ui divided stackable grid" ]
                    [ div
                        [ class "left-padded twelve wide column" ]
                        [ viewStatistics model.currentTime (FileSystem.allTasks model.fs)
                        , itemView
                        ]
                    , div [ class "four wide column" ] [ viewTodo model.currentTime (FileSystem.allTasks model.fs) ]
                    ]

            _ ->
                viewNotice model.notice
        ]


viewNotice : Notice -> Html Msg
viewNotice notice =
    case notice of
        NoNotice ->
            div [] []

        AskConfirmDeleteAccount ->
            div [ class "confirmdeleteaccount" ]
                [ p [] [ text "Woah! Are you sure you want to delete your account?" ]
                , p [] [ text "This will not delete any of your tasks that are on your devices. They will continue to work offline." ]
                , p [] [ text "All records of you in all our online systems will be removed except for payment records. Your tasks and folders will not sync anymore." ]
                , p [] [ text "Your current subscription with the service will be cancelled, and you will no longer get charged" ]
                , p [] [ text "You will need to create a new account to get another subscription for this service" ]
                , p [] [ text "Are you sure you want to delete your account?" ]
                , button [ class "ui green button", onClick CancelConfirmDeleteAccount ] [ text "No, go back" ]
                , button [ class "ui red button", onClick DeleteAccount ] [ text "Yes I'm sure. Delete my account" ]
                ]

        AskForSubscription ->
            div [ class "askforsubscription" ]
                [ p [] [ text "Welcome to the May!" ]
                , button [ class "ui green button", onClick RequestSubscription ] [ text "Get Subscription" ]
                , p [] [ text "If you don't want a subscription, you don't need an account. Everything will still work offline" ]
                , button [ class "ui red button", onClick DeleteAccount ] [ text "Delete Account" ]
                ]


viewHeader : Model -> Html Msg
viewHeader model =
    let
        status =
            case model.authState of
                Auth.Authenticated _ ->
                    case model.syncStatus of
                        SyncOffline ->
                            "Offline"

                        Synced ->
                            "Synced"

                        Retreiving ->
                            "Retreiving"

                        RetreiveFailed ->
                            "RetrieveFailed"

                        Updating ->
                            "Updating"

                        UpdateFailed ->
                            "UpdateFailed"

                _ ->
                    Auth.authStateToString model.authState
    in
    nav [ class "ui purple inverted menu top-menu" ]
        [ a [ class "item" ] [ text "May" ]
        , ul [ class "right menu" ]
            (li [ class "item" ] [ text status ]
                :: (case model.authState of
                        Auth.Authenticated _ ->
                            [ li [ class "item" ] [ button [ class "ui button red", onClick ConfirmDeleteAccount ] [ text "Delete Account" ] ]
                            , li [ class "item" ] [ button [ class "ui button grey", onClick Logout ] [ text "Logout" ] ]
                            ]

                        _ ->
                            [ a
                                [ href "https://auth.may.hazelfire.net/oauth2/authorize?client_id=1qu0jlg90401pc5lf41jukbd15&redirect_uri=https://may.hazelfire.net/&response_type=code&scopes=account.delete%20nodes.read%20nodes.write%20subscription.read%20account.delete"
                                , class "item green"
                                ]
                                [ text "Login" ]
                            ]
                   )
            )
        ]


viewTodo : Maybe Time.Posix -> List Task -> Html Msg
viewTodo nowM tasks =
    case nowM of
        Just now ->
            let
                labeledTasks =
                    Statistics.labelTasks now tasks

                addDurations =
                    List.map (\x -> ( x, Just (Task.duration x) ))

                addNothing =
                    List.map (\x -> ( x, Nothing ))

                mapJustSecond =
                    List.map (\( x, a ) -> ( x, Just a ))

                sections =
                    if List.length labeledTasks.overdue > 0 then
                        [ viewTodoSection "red" "Overdue" (addDurations labeledTasks.overdue) ]

                    else
                        []

                sectionsToday =
                    if List.length labeledTasks.doToday > 0 then
                        viewTodoSection "orange" "Do Today" (addDurations labeledTasks.doToday) :: sections

                    else
                        sections

                sectionsSoon =
                    if List.length labeledTasks.doSoon > 0 then
                        viewTodoSection "green" "Do Soon" (mapJustSecond labeledTasks.doSoon) :: sectionsToday

                    else
                        sectionsToday

                allSections =
                    if List.length labeledTasks.doLater > 0 then
                        viewTodoSection "black" "Do Later" (addNothing labeledTasks.doLater) :: sectionsSoon

                    else
                        sectionsSoon
            in
            div [ class "todo" ]
                (List.reverse allSections)

        Nothing ->
            div [] [ text "loading" ]


viewTodoSection : String -> String -> List ( Task, Maybe Float ) -> Html Msg
viewTodoSection color title tasks =
    let
        sortedTasks =
            List.sortBy (\( _, a ) -> -(Maybe.withDefault 0 a)) tasks
    in
    div []
        (h3 [ class <| "ui header " ++ color ] [ text title ]
            :: List.map
                (\( task, urgency ) ->
                    let
                        label =
                            case urgency of
                                Just u ->
                                    showFloat u ++ " (" ++ String.fromInt (floor (u / Task.duration task * 100)) ++ "%): "

                                Nothing ->
                                    ""
                    in
                    div [ class "todoitem" ]
                        [ a [ onClick (SetView (ViewIdTask (Task.id task))) ] [ text <| label ++ Task.name task ]
                        ]
                )
                sortedTasks
        )


showFloat : Float -> String
showFloat float =
    let
        base =
            round (float * 100)

        beforeDecimal =
            base // 100

        afterDecimal =
            String.padLeft 2 '0' (String.fromInt (modBy 100 base))
    in
    String.fromInt beforeDecimal ++ "." ++ afterDecimal


showHours : Float -> String
showHours float =
    let
        base =
            round (float * 100)

        beforeDecimal =
            base // 100

        afterDecimalInt =
            floor <| (float - toFloat beforeDecimal) * 60

        afterDecimal =
            String.padLeft 2 '0' (String.fromInt afterDecimalInt)
    in
    String.fromInt beforeDecimal ++ ":" ++ afterDecimal


tomorrow : Time.Posix -> Time.Posix
tomorrow time =
    Time.millisToPosix (Time.posixToMillis time + 60 * 60 * 1000 * 24)


viewStatistics : Maybe Time.Posix -> List Task -> Html Msg
viewStatistics nowM tasks =
    case nowM of
        Just now ->
            div [ class "ui statistics" ]
                [ viewStatistic "Urgency" (showHours <| Statistics.urgency now tasks)
                , viewStatistic "Tomorrow" (showHours <| Statistics.urgency (tomorrow now) tasks)
                ]

        Nothing ->
            div [] [ text "Loading" ]


viewStatistic : String -> String -> Html msg
viewStatistic label value =
    div [ class "ui small statistic" ] [ div [ class "value" ] [ text value ], div [ class "label" ] [ text label ] ]


viewButton : String -> String -> msg -> Html msg
viewButton color name message =
    button [ class <| "ui button " ++ color, onClick message ] [ text name ]


viewFolderDetails : Time.Posix -> FolderView -> FileSystem -> Html Msg
viewFolderDetails time folderView fs =
    let
        folderId =
            folderView.id

        confirmDelete =
            case folderView.editing of
                ConfirmingDeleteFolder ->
                    True

                _ ->
                    False

        editingName =
            case folderView.editing of
                EditingFolderName _ ->
                    True

                _ ->
                    False
    in
    if folderId == Id.rootId then
        div []
            [ div [ class "ui header attached top" ]
                [ text "My Tasks"
                ]
            , div [ class "ui segment attached" ]
                [ h3 [ class "ui header clearfix" ]
                    [ text "Folders"
                    , viewButton "right floated primary" "Add" (CreateFolder folderId)
                    ]
                , viewFolderList time folderId fs
                ]
            , div [ class "ui segment attached" ]
                [ h3 [ class "ui header clearfix" ]
                    [ text "Tasks"
                    , viewButton "right floated primary" "Add" (CreateTask folderId)
                    ]
                , viewTaskList time folderId fs
                ]
            ]

    else
        case FileSystem.getFolder folderId fs of
            Just folder ->
                let
                    nameText =
                        case folderView.editing of
                            EditingFolderName name ->
                                name

                            _ ->
                                Folder.name folder
                in
                div []
                    ((if confirmDelete then
                        [ div [ class "ui modal active" ]
                            [ div [ class "header" ] [ text "Confirm Delete" ]
                            , div [ class "content" ]
                                [ div [ class "description" ]
                                    [ p [] [ text "Are you sure that you want to delete this folder?" ] ]
                                ]
                            , div [ class "actions" ]
                                [ div [ class "ui black deny button", onClick CloseConfirmDeleteFolder ]
                                    [ text "Cancel" ]
                                , button [ class "ui positive button", onClick (DeleteFolder folderId) ] [ text "Delete" ]
                                ]
                            ]
                        ]

                      else
                        []
                     )
                        ++ [ ul [ class "ui menu attached top" ]
                                [ li [ class "item" ] [ viewBackButton (FileSystem.folderParent folderId fs) ]
                                , li [ class "item header-name" ] [ editableField editingName "foldername" nameText (StartEditingFolderName nameText) ChangeFolderName (restrictMessage (\x -> String.length x > 0) (SetFolderName folderId)) ]
                                , ul [ class "right menu" ] [ li [ class "item" ] [ viewButton "red" "Delete" ConfirmDeleteFolder ] ]
                                ]
                           , div [ class "ui segment attached" ]
                                [ h3 [ class "ui header clearfix" ]
                                    [ text "Folders"
                                    , viewButton "right floated primary" "Add" (CreateFolder folderId)
                                    ]
                                , viewFolderList time folderId fs
                                ]
                           , div [ class "ui segment attached" ]
                                [ h3 [ class "ui header clearfix" ]
                                    [ text "Tasks"
                                    , viewButton "right floated primary" "Add" (CreateTask folderId)
                                    ]
                                , viewTaskList time folderId fs
                                ]
                           ]
                    )

            Nothing ->
                div [ class "ui header attached top" ] [ text "Could not find folder" ]


viewTaskDetails : TaskView -> FileSystem -> Html Msg
viewTaskDetails taskView fs =
    let
        taskId =
            taskView.id

        confirmDelete =
            case taskView.editing of
                ConfirmingDeleteTask ->
                    True

                _ ->
                    False

        editingName =
            case taskView.editing of
                EditingTaskName _ ->
                    True

                _ ->
                    False

        editingDuration =
            case taskView.editing of
                EditingTaskDuration _ ->
                    True

                _ ->
                    False
    in
    case FileSystem.getTask taskId fs of
        Just task ->
            let
                nameText =
                    case taskView.editing of
                        EditingTaskName name ->
                            name

                        _ ->
                            Task.name task

                durationText =
                    case taskView.editing of
                        EditingTaskDuration duration ->
                            duration

                        _ ->
                            String.fromFloat (Task.duration task)
            in
            div []
                ((if confirmDelete then
                    [ div [ class "ui modal active" ]
                        [ div [ class "header" ] [ text "Confirm Delete" ]
                        , div [ class "content" ]
                            [ div [ class "description" ]
                                [ p [] [ text "Are you sure that you want to delete this task?" ] ]
                            ]
                        , div [ class "actions" ]
                            [ div [ class "ui black deny button", onClick CloseConfirmDeleteTask ]
                                [ text "Cancel" ]
                            , div [ class "ui positive button", onClick (DeleteTask taskId) ] [ text "Delete" ]
                            ]
                        ]
                    ]

                  else
                    []
                 )
                    ++ [ ul [ class "ui menu attached top" ]
                            [ li [ class "item" ] [ viewBackButton (FileSystem.taskParent taskId fs) ]
                            , li [ class "item header-name" ] [ editableField editingName "taskname" nameText (StartEditingTaskName nameText) ChangeTaskName (restrictMessage (\x -> String.length x > 0) (SetTaskName taskId)) ]
                            , ul [ class "right menu" ] [ li [ class "item" ] [ viewButton "red" "Delete" ConfirmDeleteTask ] ]
                            ]
                       , div [ class "ui segment attached" ]
                            [ div [ class "durationtitle" ] [ text "Duration" ]
                            , span [ class "durationvalue" ] [ editableField editingDuration "taskduration" durationText StartEditingTaskDuration ChangeTaskDuration (parseFloatMessage (SetTaskDuration taskId)) ]
                            , span [ class "durationlabel" ] [ text " hours" ]
                            , viewDueField task
                            ]
                       ]
                )

        Nothing ->
            div [ class "ui header attached top" ] [ text "Could not find task" ]


parseDate : String -> Maybe Time.Posix
parseDate date =
    Iso8601.toTime (date ++ "T00:00:00")
        |> Result.toMaybe


viewDueField : Task -> Html Msg
viewDueField task =
    case Task.due task of
        Just dueDate ->
            div []
                [ div [ class "ui checkbox" ] [ input [ type_ "checkbox", checked True, onClick (SetTaskDue (Task.id task) Nothing) ] [], label [] [ text "Remove Due Date" ] ]
                , div [ class "ui input" ]
                    [ input [ type_ "date", value (Date.toIsoString (Date.fromPosix Time.utc dueDate)), onInput (restrictMessageMaybe (parseDate >> Maybe.map Just) (SetTaskDue (Task.id task))) ] []
                    ]
                ]

        Nothing ->
            div []
                [ div [ class "ui checkbox" ]
                    [ input [ type_ "checkbox", checked False, onClick (SetTaskDueNow <| Task.id task) ] []
                    , label [] [ text "Include Due Date" ]
                    ]
                ]


parseFloatMessage : (Float -> Msg) -> String -> Msg
parseFloatMessage msg =
    restrictMessageMaybe String.toFloat msg


{-| This function returns the given message only when a condition holds on the input.
-}
restrictMessageMaybe : (a -> Maybe b) -> (b -> Msg) -> a -> Msg
restrictMessageMaybe cond msg input =
    case cond input of
        Just x ->
            msg x

        Nothing ->
            NoOp


{-| This function returns the given message only when a condition holds on the input.
-}
restrictMessage : (a -> Bool) -> (a -> Msg) -> a -> Msg
restrictMessage cond msgFunc input =
    if cond input then
        msgFunc input

    else
        NoOp


onEnter : Msg -> Attribute Msg
onEnter message =
    on "keydown" (D.map (restrictMessage ((==) 13) (always message)) keyCode)


editableField : Bool -> String -> String -> Msg -> (String -> Msg) -> (String -> Msg) -> Html Msg
editableField editing elementId name currentlyEditingMsg workingMsg setValue =
    if editing then
        div [ class "ui input editablefield" ] [ input [ id elementId, onEnter (setValue name), onBlur (setValue name), onInput workingMsg, value name ] [] ]

    else
        span [ onClick currentlyEditingMsg ] [ text name ]


viewBackButton : Maybe (Id Folder) -> Html Msg
viewBackButton parentId =
    case parentId of
        Just pid ->
            button [ class "ui button aligned left", onClick (SetView (ViewIdFolder pid)) ] [ text "Back" ]

        Nothing ->
            button [ class "ui button aligned left disabled" ] [ text "Back" ]


viewFolderList : Time.Posix -> Id Folder -> FileSystem -> Html Msg
viewFolderList time folderId fs =
    let
        childrenFolders =
            FileSystem.foldersInFolder folderId fs

        taskLabels =
            Statistics.labelTasks time (FileSystem.allTasks fs)

        labeledFolders =
            List.map (\folder -> ( folder, Statistics.folderLabelWithId taskLabels (Folder.id folder) fs )) childrenFolders
    in
    viewCards (List.map (\( folder, label ) -> viewFolderCard label folder) labeledFolders)


viewTaskList : Time.Posix -> Id Folder -> FileSystem -> Html Msg
viewTaskList time folderId fs =
    let
        childrenTasks =
            FileSystem.tasksInFolder folderId fs

        taskLabels =
            Statistics.labelTasks time (FileSystem.allTasks fs)

        labeledTasks =
            List.map (\task -> ( task, Statistics.taskLabelWithId taskLabels (Task.id task) )) childrenTasks
    in
    viewCards (List.map (\( task, label ) -> viewTaskCard label task) labeledTasks)


viewCards : List (Html Msg) -> Html Msg
viewCards cards =
    div [ class "ui cards" ] cards


viewIcon : String -> Html msg
viewIcon icon =
    i [ class <| "icon " ++ icon ] []


labelToColor : Statistics.Label -> String
labelToColor label =
    case label of
        Statistics.Overdue ->
            "red"

        Statistics.DoToday ->
            "orange"

        Statistics.DoSoon ->
            "green"

        Statistics.DoLater ->
            "black"


viewFolderCard : Statistics.Label -> Folder -> Html Msg
viewFolderCard label folder =
    a [ class "ui card", onClick (SetView (ViewIdFolder (Folder.id folder))) ]
        [ div [ class "content" ] [ div [ class "header" ] [ viewIcon <| "folder " ++ labelToColor label, text (Folder.name folder) ] ] ]


viewTaskCard : Statistics.Label -> Task -> Html Msg
viewTaskCard label task =
    a [ class "ui card", onClick (SetView (ViewIdTask (Task.id task))) ]
        [ div [ class "content" ] [ div [ class "header" ] [ viewIcon <| "tasks " ++ labelToColor label, text (Task.name task) ] ] ]
