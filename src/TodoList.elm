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

import Api.Mutation
import Api.Object.Me
import Api.Query
import Axis
import Browser
import Date
import Graphql.Http
import Graphql.Operation as Graphql
import Graphql.SelectionSet as Graphql
import Html exposing (Attribute, Html, a, button, div, h3, h5, i, input, label, li, nav, p, span, text, ul)
import Html.Attributes exposing (checked, class, href, id, target, type_, value)
import Html.Events exposing (keyCode, on, onBlur, onClick, onInput)
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
import May.Urls as Urls
import Random
import Scale
import Task
import Time
import TypedSvg as Svg
import TypedSvg.Attributes as Svg
import TypedSvg.Attributes.InPx as SvgPx
import TypedSvg.Core as Svg
import TypedSvg.Events as Svg
import TypedSvg.Types as Svg


type alias Model =
    { fs : FileSystem
    , viewing : ViewType
    , currentTime : Maybe Time.Posix
    , currentZone : Maybe Time.Zone
    , authState : Auth.AuthState
    , syncStatus : SyncStatus
    , notice : Notice
    }


type Notice
    = NoNotice
    | AskForSubscription
    | AskConfirmDeleteAccount
    | AskForLogin
    | ShowHelp


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
    | ViewTypeStatistics


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
    | GotSubscriptionSessionId (Result (Graphql.Http.Error String) String)
    | GotNodes (Result (Graphql.Http.Error FileSystem.FSUpdate) FileSystem.FSUpdate)
    | GotUpdateSuccess (Result (Graphql.Http.Error Bool) Bool)
    | GotSubscriptionCheck (Result (Graphql.Http.Error Bool) Bool)
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
    | SetTaskDoneOn (Id Task) (Maybe Time.Posix)
    | SetView ViewId
    | SetTime Time.Posix
    | SetZone Time.Zone
    | ConfirmDeleteFolder
    | CloseConfirmDeleteFolder
    | DeleteFolder (Id Folder)
    | ConfirmDeleteTask
    | CloseConfirmDeleteTask
    | DeleteTask (Id Task)
    | Logout
    | LogInConfirm
    | ConfirmDeleteAccount
    | ClearNotices
    | DeleteAccount
    | GotDeleteAccount (Result (Graphql.Http.Error Bool) Bool)
    | CancelAskForLogin
    | ShowHelpNotice
    | ViewUrgency
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
    let
        requiredActions =
            [ Time.now |> Task.perform SetTime
            , Time.here |> Task.perform SetZone
            ]
    in
    case D.decodeValue flagDecoder flagsValue of
        Ok flags ->
            let
                initModel =
                    { fs = flags.fs
                    , viewing = ViewTypeFolder { id = FileSystem.getRootId flags.fs, editing = NotEditingFolder }
                    , currentTime = Nothing
                    , authState = Auth.Unauthenticated
                    , syncStatus = SyncOffline
                    , notice = NoNotice
                    , currentZone = Nothing
                    }
            in
            case ( flags.authCode, flags.authTokens ) of
                ( Just authCode, _ ) ->
                    ( { initModel | authState = Auth.Authenticating }, Cmd.batch (Auth.exchangeAuthCode GotAuthResponse authCode :: requiredActions) )

                ( _, Just tokens ) ->
                    if Auth.hasSubscription tokens then
                        ( { initModel | authState = Auth.Authenticated tokens, syncStatus = Retreiving }, Cmd.batch (requestNodes tokens :: requiredActions) )

                    else
                        ( { initModel | authState = Auth.SubscriptionNeeded tokens, notice = AskForSubscription }, Cmd.batch (checkSubscription tokens :: requiredActions) )

                _ ->
                    ( initModel, Cmd.batch requiredActions )

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
                        , currentZone = Nothing
                        }
            in
            ( model, Cmd.batch (command :: requiredActions) )


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

        SetZone zone ->
            pure <| { model | currentZone = Just zone }

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
            case ( model.currentTime, model.currentZone ) of
                ( Just now, Just here ) ->
                    saveToLocalStorageAndUpdate <| mapFileSystem (FileSystem.mapOnTask tid (Task.setDue (Just (addWeek here now)))) model

                _ ->
                    pure model

        SetTaskDoneOn tid doneOn ->
            saveToLocalStorageAndUpdate <| mapFileSystem (FileSystem.mapOnTask tid (Task.setDoneOn doneOn)) model

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
            if Auth.hasSubscription response then
                let
                    ( newModel, command ) =
                        saveToLocalStorage { model | authState = Auth.Authenticated response, syncStatus = Retreiving }
                in
                ( newModel, Cmd.batch [ command, requestNodes response ] )

            else
                saveToLocalStorage <| { model | authState = Auth.SubscriptionNeeded response, notice = AskForSubscription }

        RequestSubscription ->
            case Auth.stateAuthTokens model.authState of
                Just authResponse ->
                    ( model, requestSubscription authResponse )

                _ ->
                    pure model

        GotSubscriptionSessionId (Ok sessionId) ->
            ( model, openStripe sessionId )

        GotSubscriptionSessionId (Err _) ->
            case Auth.stateAuthTokens model.authState of
                Just tokens ->
                    pure <| { model | authState = Auth.SubscriptionRequestFailed tokens }

                Nothing ->
                    pure model

        GotSubscriptionCheck (Err _) ->
            withTokens model <|
                \tokens ->
                    pure { model | authState = Auth.CheckingSubscriptionFailed tokens }

        GotSubscriptionCheck (Ok True) ->
            case Auth.stateAuthTokens model.authState of
                Just tokens ->
                    ( { model | authState = Auth.Authenticated tokens, syncStatus = Retreiving, notice = NoNotice }, requestNodes tokens )

                Nothing ->
                    pure model

        GotSubscriptionCheck (Ok False) ->
            withTokens model <|
                \tokens ->
                    pure <| { model | authState = Auth.SubscriptionNeeded tokens }

        GotNodes (Ok fsUpdate) ->
            case Auth.stateAuthTokens model.authState of
                Just authResponse ->
                    let
                        needsSync =
                            FileSystem.needsSync model.fs

                        ( newModel, command ) =
                            saveToLocalStorage
                                { model
                                    | fs = FileSystem.updateFS fsUpdate model.fs
                                    , syncStatus =
                                        if needsSync then
                                            Updating

                                        else
                                            Synced
                                }
                    in
                    ( newModel
                    , Cmd.batch
                        (command
                            :: (if needsSync then
                                    [ sendSyncList authResponse (FileSystem.syncList model.fs) ]

                                else
                                    []
                               )
                        )
                    )

                _ ->
                    pure model

        GotNodes (Err _) ->
            pure <| { model | syncStatus = RetreiveFailed }

        GotUpdateSuccess (Err _) ->
            pure <| { model | syncStatus = UpdateFailed }

        GotUpdateSuccess (Ok _) ->
            let
                newSyncList =
                    SyncList.remove25 (FileSystem.syncList model.fs)
            in
            if SyncList.needsSync newSyncList then
                withTokens model <|
                    \tokens ->
                        ( { model | syncStatus = Synced, fs = FileSystem.setSyncList newSyncList model.fs }, sendSyncList tokens newSyncList )

            else
                pure <| { model | syncStatus = Synced, fs = FileSystem.emptySyncList model.fs }

        Logout ->
            saveToLocalStorage <| { model | syncStatus = SyncOffline, authState = Auth.Unauthenticated }

        ConfirmDeleteAccount ->
            pure <| { model | notice = AskConfirmDeleteAccount }

        ClearNotices ->
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

        LogInConfirm ->
            pure <| { model | notice = AskForLogin }

        CancelAskForLogin ->
            pure <| { model | notice = NoNotice }

        ShowHelpNotice ->
            pure <| { model | notice = ShowHelp }

        ViewUrgency ->
            case model.viewing of
                ViewTypeStatistics ->
                    pure <| { model | viewing = newFolderView (FileSystem.getRootId model.fs) }

                _ ->
                    pure <| { model | viewing = ViewTypeStatistics }

        NoOp ->
            pure model


backendBase : String
backendBase =
    Urls.backendBase


withTokens : Model -> (Auth.AuthTokens -> ( Model, Cmd msg )) -> ( Model, Cmd msg )
withTokens model callback =
    case Auth.stateAuthTokens model.authState of
        Just tokens ->
            callback tokens

        Nothing ->
            pure model


sendSyncList : Auth.AuthTokens -> SyncList -> Cmd Msg
sendSyncList tokens synclist =
    SyncList.syncListMutation synclist
        |> Graphql.Http.mutationRequest (backendBase ++ "/")
        |> Auth.withGqlAuthHeader tokens
        |> Graphql.Http.send GotUpdateSuccess


requestNodes : Auth.AuthTokens -> Cmd Msg
requestNodes tokens =
    FileSystem.updateSelectionSet
        |> Graphql.Http.queryRequest (backendBase ++ "/")
        |> Auth.withGqlAuthHeader tokens
        |> Graphql.Http.send GotNodes


checkSubscription : Auth.AuthTokens -> Cmd Msg
checkSubscription tokens =
    checkSubscriptionSelectionSet
        |> Graphql.Http.queryRequest (backendBase ++ "/")
        |> Auth.withGqlAuthHeader tokens
        |> Graphql.Http.send GotSubscriptionCheck


checkSubscriptionSelectionSet : Graphql.SelectionSet Bool Graphql.RootQuery
checkSubscriptionSelectionSet =
    Api.Query.me Api.Object.Me.subscription


requestSubscription : Auth.AuthTokens -> Cmd Msg
requestSubscription tokens =
    requestSubscriptionSelectionSet
        |> Graphql.Http.mutationRequest (backendBase ++ "/")
        |> Auth.withGqlAuthHeader tokens
        |> Graphql.Http.send GotSubscriptionSessionId


requestSubscriptionSelectionSet : Graphql.SelectionSet String Graphql.RootMutation
requestSubscriptionSelectionSet =
    Api.Mutation.requestSubscriptionSession


saveToLocalStorage : Model -> ( Model, Cmd msg )
saveToLocalStorage =
    withCommand (\model -> setLocalStorage (encodeFlags (Flags Nothing (Auth.stateAuthTokens model.authState) model.fs)))


saveToLocalStorageAndUpdate : Model -> ( Model, Cmd Msg )
saveToLocalStorageAndUpdate model =
    case Auth.stateAuthTokens model.authState of
        Just tokens ->
            let
                needsSync =
                    FileSystem.needsSync model.fs

                sendSyncLists =
                    sendSyncList tokens (FileSystem.syncList model.fs)

                ( newModel, command ) =
                    saveToLocalStorage model
            in
            ( { newModel
                | syncStatus =
                    if needsSync then
                        Updating

                    else
                        Synced
              }
            , Cmd.batch
                (command
                    :: (if needsSync then
                            [ sendSyncLists ]

                        else
                            []
                       )
                )
            )

        Nothing ->
            saveToLocalStorage model


withCommand : (a -> Cmd msg) -> a -> ( a, Cmd msg )
withCommand commandFunc model =
    ( model, commandFunc model )


addWeek : Time.Zone -> Time.Posix -> Time.Posix
addWeek _ time =
    Time.millisToPosix <| Time.posixToMillis (Statistics.startOfDay Time.utc time) + (1000 * 60 * 60 * 24 * 7)


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
    case ( model.currentZone, model.currentTime ) of
        ( Just here, Just now ) ->
            let
                itemView =
                    case model.viewing of
                        ViewTypeFolder folderView ->
                            viewFolderDetails here now folderView model.fs

                        ViewTypeTask taskView ->
                            viewTaskDetails here now taskView model.fs

                        ViewTypeStatistics ->
                            viewStatisticsDetails here now model
            in
            div []
                [ viewHeader model
                , case model.notice of
                    NoNotice ->
                        div [ class "ui divided stackable grid" ]
                            [ div
                                [ class "left-padded twelve wide column" ]
                                [ viewStatistics model.currentZone model.currentTime (FileSystem.allTasks model.fs)
                                , itemView
                                ]
                            , div [ class "four wide column" ] [ viewTodo model.currentZone model.currentTime (FileSystem.allTasks model.fs) ]
                            ]

                    _ ->
                        viewNotice model
                ]

        _ ->
            div [] [ text "loading" ]


viewNotice : Model -> Html Msg
viewNotice model =
    let
        notice =
            model.notice
    in
    case notice of
        NoNotice ->
            div [] []

        AskConfirmDeleteAccount ->
            div [ class "notice confirmdeleteaccount" ]
                [ div
                    [ class "noticecontent" ]
                    [ h3 [] [ text "Woah! Are you sure you want to delete your account?" ]
                    , p [] [ text "Deleting your account will stop your subscription. You will no longer be charged for this service. All records of you in all our online systems will be removed except for payment records. Your tasks and folders will not sync anymore." ]
                    , p [] [ text "This will not delete any of your tasks or folders. The application will continue to work without an account." ]
                    , p [] [ text "Are you sure you want to delete your account?" ]
                    , button [ class "ui green button", onClick ClearNotices ] [ text "No, go back" ]
                    , button [ class "ui red button", onClick DeleteAccount ] [ text "Yes I'm sure. Delete my account" ]
                    ]
                ]

        AskForSubscription ->
            div [ class "notice askforsubscription" ]
                [ div
                    [ class "noticecontent" ]
                    [ h3 [] [ text "Welcome to May!" ]
                    , p [] [ text "A May account requires a subscription. The subscription costs $10 AUD a month and is charged through ", a [ href "https://stripe.com/" ] [ text "Stripe" ], text ". If you made a mistake and don't want a subscription, you can delete your account. All your tasks and folders will still be saved." ]
                    , button [ class "ui green button", onClick RequestSubscription ] [ text "Get Subscription" ]
                    , button [ class "ui red button", onClick DeleteAccount ] [ text "Remove Account" ]
                    ]
                ]

        AskForLogin ->
            div [ class "notice askforlogin" ]
                [ div
                    [ class "noticecontent" ]
                    [ h3 [] [ text "Are you sure you want an account?" ]
                    , p [] [ text "May works a bit differently from most web services. The free version of this application works fine without an account. Getting an account offers you the ability to sync your tasks and folders between your devices." ]
                    , p [] [ text "There is no such thing as a free account on May. Getting an account requires a subscription. This subscription costs $10 (AUD) a month, for which I donate $5 to ", a [ href "https://effectivealtruism.org.au/", target "_blank" ] [ text "Effective Altruism Australia" ] ]
                    , p [] [ text "If you want an account, go ahead and get one. Otherwise, you can go back to the free version." ]
                    , p [] [ text "By signing up for an account, you agree to our ", a [ href "/tos", target "_black" ] [ text "terms of service" ], text " and our ", a [ href "/privacy", target "_black" ] [ text "privacy policy" ] ]
                    , a [ class "ui green button", href Urls.loginUrl ] [ text "Get Account" ]
                    , button [ class "ui grey button", onClick CancelAskForLogin ] [ text "Back to free" ]
                    ]
                ]

        ShowHelp ->
            div [ class "help notice" ]
                [ div
                    [ class "noticecontent" ]
                    [ h3 [] [ text "May help" ]
                    , p [] [ text "May is an application that can prioritise and give you insight into your tasks. It was built by Sam Nolan." ]
                    , h5 [] [ text "Tasks and Folders" ]
                    , p [] [ text "May has tasks and folders. Folders are simply meant for you to organise where your tasks go. No calculations are done on the folders." ]
                    , p [] [ text "Tasks are things that need to get done. Tasks have a duration and a due date. If you want the full capability of May, your tasks should have a duration larger than 0 and a due date." ]
                    , h5 [] [ text "Statistics" ]
                    , p [] [ text "Urgency represents the amount of work that is recommended that you do today to get all your tasks done by their due dates. If you work less than this amount, then you will need to work more later. If you work more than this amount, then you will need to work less later." ]
                    , p [] [ text "Done today sums up the amount of work that you have completed today, so that you can track your progress towards your urgency. Tomorrow is what your urgency will be tomorrow." ]
                    , h5 [] [ text "Todo list" ]
                    , p [] [ text "All tasks that are in May that are not done are in the todo list. The todo list has different sections." ]
                    , p [] [ text "Any tasks that are overdue go into an Overdue list." ]
                    , p [] [ text "Any task that May recommends that you complete today go into the Do Today list. Each task will have a percentage representing the extent that it recommends you complete the task." ]
                    , p [] [ text "A task that if you were to complete would reduce your urgency go in the Do Soon list. Next to the task will be a date that May recommends that you complete the task by." ]
                    , p [] [ text "A task that if you were to complete makes you no less busy, and does not reduce your urgency go in the Do Later list. Due dates are also given for this list" ]
                    , p [] [ text "Any task that May cannot do calculation for because they are missing information (duration and due date) go in the No Info list." ]
                    , p [] [ text "Any task that you complete today goes in the Done Today list." ]
                    , p [] [ text "Your tasks and folders are coloured according to the section that they fall under." ]
                    , h5 [] [ text "Syncing, Subscriptions and Accounts" ]
                    , p [] [ text "May works a bit differently from most services. The application will work fine without an account. Getting an account allows you to sync your tasks between your devices, and requires also getting a subscription that costs $10 AUD, for which I donate $5 to ", a [ href "https://effectivealtruism.org.au/", target "_blank" ] [ text "Effective Altruism Australia" ], text ". There is no such thing as a free account on May." ]
                    , p [] [ text "You can cancel your subscription at any time, and you tasks will still be on your devices, they just won't sync anymore." ]
                    , h5 [] [ text "Privacy and Terms of Service" ]
                    , p [] [ text "I value your privacy, feel free to value my ", a [ href "/privacy" ] [ text "privacy policy" ], text ". If you have a subscription with May, you agree to my ", a [ href "/tos" ] [ text "terms of service" ], text "." ]
                    , h5 [] [ text "Contact" ]
                    , p [] [ text "If you have any questions, feature requests or just want to say hi, you can contact Sam Nolan at ", a [ href "mailto:sam@hazelfire.net" ] [ text "sam@hazelfire.net" ] ]
                    ]
                ]


viewStatisticsDetails : Time.Zone -> Time.Posix -> Model -> Html Msg
viewStatisticsDetails here now model =
    let
        tasks =
            Statistics.dueDateRecommendations here now (Statistics.doneTodayAndLater here now (FileSystem.allTasks model.fs))
    in
    div [ class "notice urgencynotice" ]
        [ h3 [] [ text "Urgency" ]
        , p [] [ text "Urgency represents the amount of hours per day you need to do to complete your tasks by their due dates" ]
        , if List.length tasks > 0 then
            div []
                [ p [] [ text "The following visualises how your urgency is calcualted" ]
                , p [] [ text "Each task is a box, the height of the chart represents your urgency and the right edge of each box represents the due date that we recommend you complete the task by. Grey boxes represent tasks you have completed and the other colours represent the labels you are familiar with." ]
                , p [] [ text "This was the best way that we could organise your tasks making urgency as low as possible. Completing tasks in the first block consist will decrease your urgency, however, doing a task in any later block would not mean you have to do any less work today." ]
                , viewGroups here now tasks
                ]

          else
            p [] [ text "You have an urgency of 0 because you do not have any tasks with both a duration larger than 0 and a due date that isn't completed" ]
        ]


viewGroups : Time.Zone -> Time.Posix -> List Statistics.LabeledTask -> Html Msg
viewGroups here now tasks =
    let
        firsttask =
            List.head tasks

        maxTime =
            List.head (List.reverse tasks) |> Maybe.andThen (.task >> Task.due)
    in
    case ( firsttask, maxTime ) of
        ( Just ft, Just max ) ->
            -- This should always be
            let
                min =
                    ft.start

                width =
                    1000

                height =
                    750

                padding =
                    30

                xscale =
                    Scale.time here ( 0, width - 2 * padding ) ( min, max )

                yscale =
                    Scale.linear ( height - 2 * padding, 0 ) ( 0, ft.urgency )

                labelTask task =
                    if Task.doneOn task.task /= Nothing then
                        Statistics.Done

                    else if Time.posixToMillis task.start < Time.posixToMillis (Statistics.endOfDay here now) then
                        Statistics.DoToday

                    else if task.urgency == ft.urgency then
                        Statistics.DoSoon

                    else
                        Statistics.DoLater
            in
            Svg.svg [ Svg.viewBox 0 0 width height ]
                [ Svg.g [ Svg.class [ "axis" ], Svg.transform [ Svg.Translate padding padding ] ]
                    [ Axis.left [ Axis.tickCount 10 ] yscale
                    ]
                , Svg.g [ Svg.class [ "axis" ], Svg.transform [ Svg.Translate padding (height - padding) ] ]
                    [ Axis.bottom [ Axis.tickCount 10 ] xscale
                    ]
                , Svg.g [ Svg.transform [ Svg.Translate padding padding ], Svg.class [ "urgencyboxes" ] ]
                    (List.map (\x -> viewUrgencyTaskBar xscale yscale (labelTask x) x) tasks)
                ]

        _ ->
            div [] []


viewUrgencyTaskBar : Scale.ContinuousScale Time.Posix -> Scale.ContinuousScale Float -> Statistics.Label -> Statistics.LabeledTask -> Svg.Svg Msg
viewUrgencyTaskBar xscale yscale label { urgency, start, task, end } =
    let
        ( max, _ ) =
            Scale.range yscale
    in
    Svg.rect
        [ SvgPx.x (Scale.convert xscale start)
        , SvgPx.y (Scale.convert yscale urgency)
        , SvgPx.width (Scale.convert xscale end - Scale.convert xscale start)
        , SvgPx.height (max - Scale.convert yscale urgency)
        , Svg.onClick (SetView (ViewIdTask (Task.id task)))
        , Svg.class
            [ case label of
                Statistics.DoSoon ->
                    "dosoonbox"

                Statistics.DoLater ->
                    "dolaterbox"

                Statistics.DoToday ->
                    "dotodaybox"

                Statistics.Done ->
                    "donebox"

                _ ->
                    ""
            , "clickable"
            ]
        ]
        []


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
        [ a
            [ class
                (if model.notice /= ShowHelp then
                    "active item"

                 else
                    "item"
                )
            , onClick ClearNotices
            ]
            [ text "May" ]
        , a
            [ class
                (if model.notice == ShowHelp then
                    "active item"

                 else
                    "item"
                )
            , onClick ShowHelpNotice
            ]
            [ text "Help" ]
        , ul [ class "right menu" ]
            [ li [ class "item" ] [ text status ]
            , li [ class "item" ]
                [ div
                    [ class <|
                        "ui simple dropdown"
                    ]
                    [ text "Account"
                    , viewIcon "dropdown"
                    , div [ class "menu" ]
                        (case model.authState of
                            Auth.Authenticated _ ->
                                [ div [ class "item", onClick ConfirmDeleteAccount ] [ text "Delete Account" ]
                                , div [ class "item", onClick Logout ] [ text "Logout" ]
                                ]

                            _ ->
                                [ div [ class "item", onClick LogInConfirm ] [ text "Create Account" ]
                                , a [ class "item", href Urls.loginUrl ] [ text "Login" ]
                                ]
                        )
                    ]
                ]
            ]
        ]


monthToNumber : Time.Month -> Int
monthToNumber month =
    case month of
        Time.Jan ->
            1

        Time.Feb ->
            2

        Time.Mar ->
            3

        Time.Apr ->
            4

        Time.May ->
            5

        Time.Jun ->
            6

        Time.Jul ->
            7

        Time.Aug ->
            8

        Time.Sep ->
            9

        Time.Oct ->
            10

        Time.Nov ->
            11

        Time.Dec ->
            12


formatTime : Time.Zone -> Time.Posix -> String
formatTime here time =
    String.fromInt (Time.toDay here time) ++ "/" ++ String.fromInt (monthToNumber <| Time.toMonth here time)


viewTodo : Maybe Time.Zone -> Maybe Time.Posix -> List Task -> Html Msg
viewTodo hereM nowM tasks =
    case ( hereM, nowM ) of
        ( Just here, Just now ) ->
            let
                labeledTasks =
                    Statistics.labelTasks here now tasks

                addDurations =
                    List.map (\x -> ( x, showHours (Task.duration x) ))

                addPercentages =
                    List.map (\( x, p ) -> ( x, showPercentage p ))

                addNothing =
                    List.map (\x -> ( x, "" ))

                addDueDates =
                    List.map (\{ task, end } -> ( task, formatTime here end ))

                sections =
                    if List.length labeledTasks.overdue > 0 then
                        [ viewTodoSection "red" "Overdue" (addNothing labeledTasks.overdue) ]

                    else
                        []

                sectionsToday =
                    if List.length labeledTasks.doToday > 0 then
                        viewTodoSection "orange" "Do Today" (addPercentages labeledTasks.doToday) :: sections

                    else
                        sections

                sectionsSoon =
                    if List.length labeledTasks.doSoon > 0 then
                        viewTodoSection "green" "Do Soon" (addDueDates labeledTasks.doSoon) :: sectionsToday

                    else
                        sectionsToday

                sectionsDoLater =
                    if List.length labeledTasks.doLater > 0 then
                        viewTodoSection "purple" "Do Later" (addDueDates labeledTasks.doLater) :: sectionsSoon

                    else
                        sectionsSoon

                sectionsNoInfo =
                    if List.length labeledTasks.noDue > 0 then
                        viewTodoSection "blue" "No Info" (addNothing labeledTasks.noDue) :: sectionsDoLater

                    else
                        sectionsDoLater

                doneToday =
                    Statistics.doneToday here now tasks

                allSections =
                    if List.length doneToday > 0 then
                        viewTodoSection "black" "Done today" (addDurations doneToday) :: sectionsNoInfo

                    else
                        sectionsNoInfo
            in
            div [ class "todo" ]
                (List.reverse allSections)

        _ ->
            div [] [ text "loading" ]


showPercentage : Float -> String
showPercentage amount =
    String.fromInt (floor (amount * 100)) ++ "%"


viewTodoSection : String -> String -> List ( Task, String ) -> Html Msg
viewTodoSection color title tasks =
    div []
        (h3 [ class <| "ui header todosectionheader " ++ color ] [ text title ]
            :: List.map
                (\( task, label ) ->
                    div [ class "todoitem" ]
                        [ a [ onClick (SetView (ViewIdTask (Task.id task))), class "clickable" ] [ text <| label ++ " " ++ Task.name task ]
                        ]
                )
                tasks
        )


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


viewStatistics : Maybe Time.Zone -> Maybe Time.Posix -> List Task -> Html Msg
viewStatistics hereM nowM tasks =
    case ( hereM, nowM ) of
        ( Just here, Just now ) ->
            div [ class "ui statistics" ]
                [ viewStatistic ViewUrgency "Done today" (showHours <| List.sum (List.map Task.duration (Statistics.doneToday here now tasks)))
                , viewStatistic ViewUrgency "Urgency" <| (showHours <| Statistics.urgency here now tasks)
                , viewStatistic ViewUrgency "Tomorrow" (showHours <| Statistics.urgency here (tomorrow now) tasks)
                ]

        _ ->
            div [] [ text "Loading" ]


viewStatistic : msg -> String -> String -> Html msg
viewStatistic msg label value =
    div [ class "ui small statistic clickable", onClick msg ]
        [ div [ class "value" ] [ text value ]
        , div [ class "label" ] [ text label ]
        ]


viewButton : String -> String -> msg -> Html msg
viewButton color name message =
    button [ class <| "ui button " ++ color, onClick message ] [ text name ]


viewFolderDetails : Time.Zone -> Time.Posix -> FolderView -> FileSystem -> Html Msg
viewFolderDetails here time folderView fs =
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
                , viewFolderList here time folderId fs
                ]
            , div [ class "ui segment attached" ]
                [ h3 [ class "ui header clearfix" ]
                    [ text "Tasks"
                    , viewButton "right floated primary" "Add" (CreateTask folderId)
                    ]
                , viewTaskList here time folderId fs
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
                                , viewFolderList here time folderId fs
                                ]
                           , div [ class "ui segment attached" ]
                                [ h3 [ class "ui header clearfix" ]
                                    [ text "Tasks"
                                    , viewButton "right floated primary" "Add" (CreateTask folderId)
                                    ]
                                , viewTaskList here time folderId fs
                                ]
                           ]
                    )

            Nothing ->
                div [ class "ui header attached top" ] [ text "Could not find folder" ]


viewTaskDetails : Time.Zone -> Time.Posix -> TaskView -> FileSystem -> Html Msg
viewTaskDetails here now taskView fs =
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
                            , ul [ class "right menu" ]
                                [ li [ class "item" ]
                                    [ case Task.doneOn task of
                                        Nothing ->
                                            div [ class "ui read-only checkbox" ]
                                                [ input [ type_ "checkbox", onClick (SetTaskDoneOn (Task.id task) (Just now)), checked False ] []
                                                , label [] [ text "Complete" ]
                                                ]

                                        Just _ ->
                                            div [ class "ui checked read-only checkbox" ]
                                                [ input [ type_ "checkbox", onClick (SetTaskDoneOn (Task.id task) Nothing), checked True ] []
                                                , label [] [ text "Complete" ]
                                                ]
                                    ]
                                , li [ class "item" ] [ viewButton "red" "Delete" ConfirmDeleteTask ]
                                ]
                            ]
                       , div [ class "ui segment attached" ]
                            [ div [ class "durationtitle" ] [ text "Duration" ]
                            , span [ class "durationvalue" ] [ editableField editingDuration "taskduration" durationText StartEditingTaskDuration ChangeTaskDuration (parseFloatMessage (SetTaskDuration taskId)) ]
                            , span [ class "durationlabel" ] [ text " hours" ]
                            , viewDueField here task
                            ]
                       ]
                )

        Nothing ->
            div [ class "ui header attached top" ] [ text "Could not find task" ]


parseDate : String -> Maybe Time.Posix
parseDate date =
    Iso8601.toTime
        (date
            ++ "T23:59:59+10:00"
        )
        |> Result.toMaybe


viewDueField : Time.Zone -> Task -> Html Msg
viewDueField zone task =
    case Task.due task of
        Just dueDate ->
            div []
                [ div [ class "ui checkbox" ] [ input [ type_ "checkbox", checked True, onClick (SetTaskDue (Task.id task) Nothing) ] [], label [] [ text "Remove Due Date" ] ]
                , div [ class "ui input" ]
                    [ input [ type_ "date", value (Date.toIsoString (Date.fromPosix zone dueDate)), onInput (restrictMessageMaybe (parseDate >> Maybe.map Just) (SetTaskDue (Task.id task))) ] []
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
        span [ onClick currentlyEditingMsg, class "clickable" ] [ text name ]


viewBackButton : Maybe (Id Folder) -> Html Msg
viewBackButton parentId =
    case parentId of
        Just pid ->
            button [ class "ui button aligned left", onClick (SetView (ViewIdFolder pid)) ] [ text "Back" ]

        Nothing ->
            button [ class "ui button aligned left disabled" ] [ text "Back" ]


viewFolderList : Time.Zone -> Time.Posix -> Id Folder -> FileSystem -> Html Msg
viewFolderList here time folderId fs =
    let
        childrenFolders =
            FileSystem.foldersInFolder folderId fs

        taskLabels =
            Statistics.labelTasks here time (FileSystem.allTasks fs)

        labeledFolders =
            List.map (\folder -> ( folder, Statistics.folderLabelWithId taskLabels (Folder.id folder) fs )) childrenFolders
    in
    viewCards (List.map (\( folder, label ) -> viewFolderCard label folder) labeledFolders)


viewTaskList : Time.Zone -> Time.Posix -> Id Folder -> FileSystem -> Html Msg
viewTaskList here time folderId fs =
    let
        childrenTasks =
            FileSystem.tasksInFolder folderId fs

        taskLabels =
            Statistics.labelTasks here time (FileSystem.allTasks fs)

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
            "purple"

        Statistics.NoDue ->
            "blue"

        Statistics.Done ->
            "black"


viewFolderCard : Statistics.Label -> Folder -> Html Msg
viewFolderCard label folder =
    a [ class "ui card", onClick (SetView (ViewIdFolder (Folder.id folder))) ]
        [ div [ class "content" ] [ div [ class "header" ] [ viewIcon <| "folder " ++ labelToColor label, text (Folder.name folder) ] ] ]


viewTaskCard : Statistics.Label -> Task -> Html Msg
viewTaskCard label task =
    a [ class "ui card", onClick (SetView (ViewIdTask (Task.id task))) ]
        [ div [ class "content" ] [ div [ class "header" ] [ viewIcon <| "tasks " ++ labelToColor label, text (Task.name task) ] ] ]
