port module TodoList exposing
    ( FolderEditing(..)
    , Model
    , Msg(..)
    , SyncStatus(..)
    , TaskEditing(..)
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
import Html exposing (Attribute, Html, a, button, code, div, h3, h5, i, input, label, li, nav, p, span, text, ul)
import Html.Attributes exposing (checked, class, draggable, href, id, novalidate, required, style, tabindex, target, type_, value)
import Html.Events exposing (keyCode, on, onBlur, onClick, onFocus, onInput, preventDefaultOn)
import Iso8601
import Json.Decode as D
import Json.Encode as E
import May.AppVariables exposing (AppVariables)
import May.Auth as Auth
import May.Background as Background
import May.FileSystem as FileSystem exposing (FileSystem)
import May.Folder as Folder exposing (Folder)
import May.Id as Id exposing (Id)
import May.Statistics as Statistics
import May.SyncList as SyncList exposing (SyncList)
import May.Task as Task exposing (Task)
import Random
import Scale
import String
import Task
import Time
import TypedSvg as Svg
import TypedSvg.Attributes as SvgAttr
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
    , retryCommand : Maybe (Cmd Msg)
    , notice : Notice
    , authCode : Maybe String
    , offset : String
    , variables : AppVariables
    , showTree : Bool
    }


type Notice
    = NoNotice
    | AskForSubscription
    | AskConfirmDeleteAccount
    | AskForLogin
    | ShowHelp
    | LocalStorageErrorNotice String


type SyncStatus
    = SyncOffline
    | Synced
    | Retreiving
    | RetreiveFailed
    | Updating
    | UpdateFailed


type ViewType
    = ViewTypeFolder FolderView
    | ViewTypeStatistics (Maybe Statistics.LabeledTask)


type alias FolderView =
    { id : Id Folder
    , editing : FolderEditing
    , viewOld : Bool
    , taskEdit : Maybe TaskView
    , currentlyDragging : Maybe ItemId
    , draggingOver : Maybe (Id Folder)
    }


type ItemId
    = FolderId (Id Folder)
    | TaskId (Id Task)


type alias TaskView =
    { id : Id Task
    , editing : TaskEditing
    }


type FolderEditing
    = NotEditingFolder
    | EditingFolderName String
    | ConfirmingDeleteFolder (Id Folder)
    | MovingFolder (Id Folder)


type TaskEditing
    = EditingTaskName String
    | EditingTaskDuration String
    | ConfirmingDeleteTask
    | MovingTask


newFolderView : Id Folder -> ViewType
newFolderView id =
    ViewTypeFolder { id = id, editing = NotEditingFolder, taskEdit = Nothing, viewOld = False, currentlyDragging = Nothing, draggingOver = Nothing }


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
    | StartEditingTaskName (Id Task) String
    | StartEditingTaskDuration (Id Task) String
    | RequestSubscription
    | StartEditingFolderName String
    | ChangeFolderName String
    | ChangeTaskName String
    | ChangeTaskDuration (Id Task) String
    | SetFolderName (Id Folder) String
    | SetTaskName (Id Task) String
    | SetTaskDuration (Id Task) Float
    | SetTaskDueNow (Id Task)
    | SetTaskDue (Id Task) (Maybe Time.Posix)
    | SetTaskDoneOn (Id Task) (Maybe Time.Posix)
    | SetView (Id Folder)
    | SetTime Time.Posix
    | SetZone Time.Zone
    | ConfirmDeleteFolder (Id Folder)
    | ClearEditing
    | DeleteFolder (Id Folder)
    | ConfirmDeleteTask (Id Task)
    | DeleteTask (Id Task)
    | SetViewOld Bool
    | Logout
    | LogInConfirm
    | ConfirmDeleteAccount
    | ClearNotices
    | DeleteAccount
    | GotDeleteAccount (Result (Graphql.Http.Error Bool) Bool)
    | CancelAskForLogin
    | ShowHelpNotice
    | ViewUrgency
    | SetUrgencyTaskHover (Maybe Statistics.LabeledTask)
    | SelectMoveFolder (Id Folder)
    | SelectMoveTask (Id Task)
    | MoveTask (Id Task) (Id Folder)
    | MoveFolder (Id Folder) (Id Folder)
    | SendRetry
    | DeleteData
    | ShareFolder (Id Folder) Bool
    | ShowTree Bool
    | StartDrag ItemId
    | EndDrag
    | DropMoveTask (Id Folder)
    | SetDraggingOver (Maybe (Id Folder))
    | NoOp


type alias Flags =
    { authCode : Maybe String
    , authTokens : Maybe E.Value
    , fs : Maybe E.Value
    , offset : String
    , appVariables : AppVariables
    }


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = \_ -> Time.every 5000.0 SetTime
        , view = view
        }


type alias LocalStorageSave =
    { authTokens : Maybe Auth.AuthTokens
    , fs : FileSystem
    }


encodeLocalStorageSave : LocalStorageSave -> E.Value
encodeLocalStorageSave save =
    case save.authTokens of
        Just tokens ->
            E.object [ ( "tokens", Auth.encodeTokens tokens ), ( "fs", FileSystem.encode save.fs ), ( "version", E.string "1" ) ]

        Nothing ->
            E.object [ ( "fs", FileSystem.encode save.fs ), ( "version", E.string "1" ) ]


{-| Initialises from storage modal
-}
init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        requiredActions =
            [ Time.now |> Task.perform SetTime
            , Time.here |> Task.perform SetZone
            ]
    in
    case flags.fs of
        Just fsValue ->
            case D.decodeValue FileSystem.decode fsValue of
                Ok fs ->
                    let
                        initModel =
                            { fs = fs
                            , viewing = newFolderView (FileSystem.getRootId fs)
                            , currentTime = Nothing
                            , authState = Auth.Unauthenticated
                            , syncStatus = SyncOffline
                            , notice = NoNotice
                            , currentZone = Nothing
                            , retryCommand = Nothing
                            , authCode = Nothing
                            , offset = flags.offset
                            , variables = flags.appVariables
                            , showTree = False
                            }
                    in
                    case ( flags.authCode, flags.authTokens ) of
                        ( Just authCode, _ ) ->
                            ( { initModel | authState = Auth.Authenticating, authCode = Just authCode }, Cmd.batch (Auth.exchangeAuthCode flags.appVariables GotAuthResponse authCode :: requiredActions) )

                        ( _, Just tokensValue ) ->
                            case D.decodeValue Auth.tokensDecoder tokensValue of
                                Ok tokens ->
                                    if Auth.hasSubscription tokens then
                                        ( { initModel | authState = Auth.Authenticated tokens, syncStatus = Retreiving }, Cmd.batch (requestNodes flags.appVariables tokens :: requiredActions) )

                                    else
                                        ( { initModel | authState = Auth.SubscriptionNeeded tokens, notice = AskForSubscription }, Cmd.batch (checkSubscription flags.appVariables tokens :: requiredActions) )

                                Err _ ->
                                    ( initModel, Cmd.batch requiredActions )

                        _ ->
                            ( initModel, Cmd.batch requiredActions )

                Err err ->
                    let
                        model =
                            emptyModel flags.appVariables
                    in
                    ( { model | notice = LocalStorageErrorNotice (D.errorToString err) }, Cmd.batch requiredActions )

        Nothing ->
            let
                firstModel =
                    emptyModel flags.appVariables

                ( model, command ) =
                    saveToLocalStorage
                        { firstModel | offset = flags.offset }
            in
            ( model, Cmd.batch (command :: requiredActions) )


emptyModel : AppVariables -> Model
emptyModel variables =
    { fs = FileSystem.new (Folder.new Id.rootId "My Tasks")
    , viewing = newFolderView Id.rootId
    , currentTime = Nothing
    , authState = Auth.Unauthenticated
    , syncStatus = SyncOffline
    , notice = NoNotice
    , currentZone = Nothing
    , authCode = Nothing
    , retryCommand = Nothing
    , offset = ""
    , variables = variables
    , showTree = False
    }


pure : a -> ( a, Cmd msg )
pure model =
    ( model, Cmd.none )


port setLocalStorage : E.Value -> Cmd msg


port setFocus : String -> Cmd msg


port setBlur : String -> Cmd msg


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
            let
                ( newModel, command ) =
                    saveToLocalStorageAndUpdate <| { model | fs = FileSystem.addTask parentId (Task.new taskId "New Task") model.fs, viewing = mapFolderView (\fv -> { fv | taskEdit = Just { id = taskId, editing = EditingTaskName "New Task" } }) model.viewing }
            in
            ( newModel, Cmd.batch [ command, setFocus "taskname" ] )

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
                        ( { newModel | authState = Auth.Authenticating }, Auth.refreshTokens model.variables GotAuthResponse tokens )

                    else
                        pure newModel

                Nothing ->
                    pure newModel

        SetView fid ->
            pure <| { model | viewing = newFolderView fid }

        StartEditingFolderName name ->
            let
                startSelect =
                    withCommand (always (setFocus "foldername")) <| mapViewing (mapFolderView (mapFolderEditing (always (EditingFolderName name)))) model
            in
            case model.viewing of
                ViewTypeFolder folderView ->
                    case folderView.editing of
                        EditingFolderName _ ->
                            pure model

                        _ ->
                            startSelect

                _ ->
                    startSelect

        StartEditingTaskName id name ->
            case model.viewing of
                ViewTypeFolder folderView ->
                    let
                        startSelect =
                            ( { model | viewing = ViewTypeFolder { folderView | taskEdit = Just { id = id, editing = EditingTaskName name } } }, setFocus "taskname" )
                    in
                    case folderView.taskEdit of
                        Just _ ->
                            pure model

                        _ ->
                            startSelect

                _ ->
                    pure model

        StartEditingTaskDuration id name ->
            case model.viewing of
                ViewTypeFolder folderView ->
                    ( { model | viewing = ViewTypeFolder { folderView | taskEdit = Just { id = id, editing = EditingTaskDuration name } } }, setFocus "taskduration" )

                _ ->
                    pure model

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

                ( newModel, command ) =
                    saveToLocalStorageAndUpdate <| mapViewing (mapFolderView (\folderView -> { folderView | taskEdit = Nothing })) fsChange
            in
            ( newModel, Cmd.batch [ command, setBlur "taskname" ] )

        ChangeTaskName newName ->
            pure <| mapViewing (mapTaskView (mapTaskEditing (always (EditingTaskName newName)))) model

        ChangeTaskDuration id newDuration ->
            pure <| mapViewing (mapFolderView (\folderView -> { folderView | taskEdit = Just { id = id, editing = EditingTaskDuration newDuration } })) model

        ChangeFolderName newName ->
            pure <| mapViewing (mapFolderView (\x -> { x | editing = EditingFolderName newName })) model

        SetTaskDuration tid duration ->
            let
                fsChange =
                    mapFileSystem (FileSystem.mapOnTask tid (Task.setDuration duration)) model

                ( newModel, command ) =
                    saveToLocalStorageAndUpdate <| mapViewing (mapFolderView (\folderView -> { folderView | taskEdit = Nothing })) fsChange
            in
            ( newModel, Cmd.batch [ command, setBlur "taskduration" ] )

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

        ConfirmDeleteTask id ->
            pure <| mapViewing (mapFolderView <| \folderView -> { folderView | taskEdit = Just { id = id, editing = ConfirmingDeleteTask } }) model

        ClearEditing ->
            pure <| mapViewing (mapFolderView (\folderView -> { folderView | editing = NotEditingFolder, taskEdit = Nothing })) model

        ConfirmDeleteFolder fid ->
            pure <| mapViewing (mapFolderView (mapFolderEditing (always (ConfirmingDeleteFolder fid)))) model

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
            case model.authCode of
                Just code ->
                    pure <| { model | authState = Auth.AuthFailed, retryCommand = Just <| Auth.exchangeAuthCode model.variables GotAuthResponse code }

                Nothing ->
                    pure <| { model | authState = Auth.AuthFailed }

        GotAuthResponse (Ok response) ->
            if Auth.hasSubscription response then
                let
                    ( newModel, command ) =
                        saveToLocalStorage { model | authState = Auth.Authenticated response, syncStatus = Retreiving }
                in
                ( newModel, Cmd.batch [ command, requestNodes model.variables response ] )

            else
                let
                    ( newModel, command ) =
                        saveToLocalStorage <| { model | authState = Auth.SubscriptionNeeded response, notice = AskForSubscription }
                in
                ( newModel, Cmd.batch [ command, checkSubscription model.variables response ] )

        RequestSubscription ->
            case Auth.stateAuthTokens model.authState of
                Just authResponse ->
                    ( model, requestSubscription model.variables authResponse )

                _ ->
                    pure model

        GotSubscriptionSessionId (Ok sessionId) ->
            ( model, openStripe sessionId )

        GotSubscriptionSessionId (Err _) ->
            withTokens model <|
                \tokens ->
                    pure <| { model | authState = Auth.SubscriptionRequestFailed tokens, retryCommand = Just <| requestSubscription model.variables tokens }

        GotSubscriptionCheck (Err _) ->
            withTokens model <|
                \tokens ->
                    pure { model | authState = Auth.CheckingSubscriptionFailed tokens }

        GotSubscriptionCheck (Ok True) ->
            case Auth.stateAuthTokens model.authState of
                Just tokens ->
                    ( { model | authState = Auth.Authenticated tokens, syncStatus = Retreiving, notice = NoNotice }, requestNodes model.variables tokens )

                Nothing ->
                    pure model

        GotSubscriptionCheck (Ok False) ->
            withTokens model <|
                \tokens ->
                    pure <| { model | authState = Auth.SubscriptionNeeded tokens, retryCommand = Just <| checkSubscription model.variables tokens }

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
                                    [ sendSyncList model.variables authResponse (FileSystem.syncList model.fs) ]

                                else
                                    []
                               )
                        )
                    )

                _ ->
                    pure model

        GotNodes (Err _) ->
            withTokens model <|
                \tokens ->
                    pure <| { model | syncStatus = RetreiveFailed, retryCommand = Just <| requestNodes model.variables tokens }

        GotUpdateSuccess (Err _) ->
            withTokens model <|
                \tokens ->
                    pure { model | syncStatus = UpdateFailed, retryCommand = Just <| sendSyncList model.variables tokens (FileSystem.syncList model.fs) }

        GotUpdateSuccess (Ok _) ->
            let
                newSyncList =
                    SyncList.remove25 (FileSystem.syncList model.fs)
            in
            if SyncList.needsSync newSyncList then
                withTokens model <|
                    \tokens ->
                        ( { model | syncStatus = Synced, fs = FileSystem.setSyncList newSyncList model.fs }, sendSyncList model.variables tokens newSyncList )

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
                    ( model, Auth.deleteUser model.variables GotDeleteAccount tokens )

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
                ViewTypeStatistics _ ->
                    pure <| { model | viewing = newFolderView (FileSystem.getRootId model.fs) }

                _ ->
                    pure <| { model | viewing = ViewTypeStatistics Nothing }

        SetViewOld filter ->
            pure <| mapViewing (mapFolderView <| \folderView -> { folderView | viewOld = filter }) model

        SetUrgencyTaskHover task ->
            pure <| { model | viewing = ViewTypeStatistics task }

        SelectMoveFolder folderId ->
            pure <| mapViewing (mapFolderView (mapFolderEditing (always (MovingFolder folderId)))) model

        SelectMoveTask taskId ->
            pure <| mapViewing (mapFolderView (\folderView -> { folderView | taskEdit = Just { id = taskId, editing = MovingTask } })) model

        MoveTask taskId folderId ->
            let
                fsUpdate =
                    mapFileSystem (FileSystem.moveTask taskId folderId) model
            in
            saveToLocalStorageAndUpdate <| mapViewing (mapFolderView (\folderView -> { folderView | taskEdit = Nothing })) fsUpdate

        MoveFolder folderId parentId ->
            let
                fsUpdate =
                    mapFileSystem (FileSystem.moveFolder folderId parentId) model
            in
            saveToLocalStorageAndUpdate <| mapViewing (mapFolderView (\folderView -> { folderView | editing = NotEditingFolder })) fsUpdate

        SendRetry ->
            case model.retryCommand of
                Just command ->
                    ( model, command )

                Nothing ->
                    pure model

        DeleteData ->
            saveToLocalStorage (emptyModel model.variables)

        ShareFolder fid shareState ->
            let
                shareWith =
                    if shareState then
                        Just []

                    else
                        Nothing

                fsChange =
                    mapFileSystem (FileSystem.mapOnFolder fid (Folder.shareWith shareWith)) model
            in
            saveToLocalStorageAndUpdate fsChange

        ShowTree state ->
            pure { model | showTree = state }

        StartDrag itemId ->
            pure <| mapViewing (mapFolderView (\folderView -> { folderView | currentlyDragging = Just itemId })) model

        EndDrag ->
            pure <| mapViewing (mapFolderView (\folderView -> { folderView | currentlyDragging = Nothing })) model

        DropMoveTask folderId ->
            case model.viewing of
                ViewTypeFolder folderView ->
                    case folderView.currentlyDragging of
                        Just itemId ->
                            let
                                fsUpdate =
                                    case itemId of
                                        FolderId childId ->
                                            if childId == folderId then
                                                model

                                            else
                                                mapFileSystem (FileSystem.moveFolder childId folderId) model

                                        TaskId taskId ->
                                            mapFileSystem (FileSystem.moveTask taskId folderId) model
                            in
                            saveToLocalStorageAndUpdate <| mapViewing (mapFolderView (\fv -> { fv | taskEdit = Nothing, currentlyDragging = Nothing, draggingOver = Nothing })) fsUpdate

                        _ ->
                            pure model

                _ ->
                    pure model

        SetDraggingOver dragId ->
            pure <| mapViewing (mapFolderView (\folderView -> { folderView | draggingOver = dragId })) model

        NoOp ->
            pure model


withTokens : Model -> (Auth.AuthTokens -> ( Model, Cmd msg )) -> ( Model, Cmd msg )
withTokens model callback =
    case Auth.stateAuthTokens model.authState of
        Just tokens ->
            callback tokens

        Nothing ->
            pure model


sendSyncList : AppVariables -> Auth.AuthTokens -> SyncList -> Cmd Msg
sendSyncList variables tokens synclist =
    SyncList.syncListMutation synclist
        |> Graphql.Http.mutationRequest (variables.apiBackendUrl ++ "/")
        |> Auth.withGqlAuthHeader tokens
        |> Graphql.Http.send GotUpdateSuccess


requestNodes : AppVariables -> Auth.AuthTokens -> Cmd Msg
requestNodes variables tokens =
    FileSystem.updateSelectionSet
        |> Graphql.Http.queryRequest (variables.apiBackendUrl ++ "/")
        |> Auth.withGqlAuthHeader tokens
        |> Graphql.Http.send GotNodes


checkSubscription : AppVariables -> Auth.AuthTokens -> Cmd Msg
checkSubscription variables tokens =
    checkSubscriptionSelectionSet
        |> Graphql.Http.queryRequest (variables.apiBackendUrl ++ "/")
        |> Auth.withGqlAuthHeader tokens
        |> Graphql.Http.send GotSubscriptionCheck


checkSubscriptionSelectionSet : Graphql.SelectionSet Bool Graphql.RootQuery
checkSubscriptionSelectionSet =
    Api.Query.me Api.Object.Me.subscription


requestSubscription : AppVariables -> Auth.AuthTokens -> Cmd Msg
requestSubscription variables tokens =
    requestSubscriptionSelectionSet
        |> Graphql.Http.mutationRequest (variables.apiBackendUrl ++ "/")
        |> Auth.withGqlAuthHeader tokens
        |> Graphql.Http.send GotSubscriptionSessionId


requestSubscriptionSelectionSet : Graphql.SelectionSet String Graphql.RootMutation
requestSubscriptionSelectionSet =
    Api.Mutation.requestSubscriptionSession


saveToLocalStorage : Model -> ( Model, Cmd msg )
saveToLocalStorage =
    withCommand (\model -> setLocalStorage (encodeLocalStorageSave (LocalStorageSave (Auth.stateAuthTokens model.authState) model.fs)))


saveToLocalStorageAndUpdate : Model -> ( Model, Cmd Msg )
saveToLocalStorageAndUpdate model =
    case Auth.stateAuthTokens model.authState of
        Just tokens ->
            let
                needsSync =
                    FileSystem.needsSync model.fs

                sendSyncLists =
                    sendSyncList model.variables tokens (FileSystem.syncList model.fs)

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
    Time.millisToPosix <| Time.posixToMillis (Statistics.endOfDay Time.utc time) + (1000 * 60 * 60 * 24 * 7)


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


mapFolderView : (FolderView -> FolderView) -> ViewType -> ViewType
mapFolderView func model =
    case model of
        ViewTypeFolder folderView ->
            ViewTypeFolder <| func folderView

        a ->
            a


mapTaskView : (TaskView -> TaskView) -> ViewType -> ViewType
mapTaskView func =
    mapFolderView <| \folderView -> { folderView | taskEdit = Maybe.map func folderView.taskEdit }


view : Model -> Html Msg
view model =
    case ( model.currentZone, model.currentTime ) of
        ( Just here, Just now ) ->
            let
                itemView =
                    case model.viewing of
                        ViewTypeFolder folderView ->
                            viewFolderDetails model.offset here now folderView model.fs

                        ViewTypeStatistics task ->
                            viewStatisticsDetails here now model task

                labeledTasks =
                    Statistics.labelTasks here now (FileSystem.allTasks model.fs)
            in
            div []
                [ Background.view here now labeledTasks
                , viewHeader model
                , case model.notice of
                    NoNotice ->
                        div
                            [ class <|
                                "mainview"
                                    ++ (if model.showTree then
                                            " hidden"

                                        else
                                            ""
                                       )
                            ]
                            [ div
                                [ class "taskview" ]
                                [ viewStatistics here now (FileSystem.allTasks model.fs)
                                , viewProgressBar here now (FileSystem.allTasks model.fs)
                                , itemView
                                ]
                            , div [ class "todoview" ] [ viewTodo model ]
                            ]

                    _ ->
                        viewNotice model
                ]

        _ ->
            div [] [ text "loading" ]


loginUrl : AppVariables -> String
loginUrl { authBase, clientId, redirectUri } =
    authBase ++ "/oauth2/authorize?client_id=" ++ clientId ++ "&redirect_uri=" ++ redirectUri ++ "&response_type=code"


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
                    , p [] [ text <| "A May account requires a subscription. The subscription costs $3 AUD a month and is charged through ", a [ href "https://stripe.com/" ] [ text "Stripe" ], text ". If you made a mistake and don't want a subscription, you can delete your account. All your tasks and folders will still be saved." ]
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
                    , p [] [ text <| "There is no such thing as a free account on May. Getting an account requires a subscription. This subscription costs $3 AUD a month." ]
                    , p [] [ text "By signing up for an account, you agree to our ", a [ href "/tos", target "_black" ] [ text "terms of service" ], text " and our ", a [ href "/privacy", target "_black" ] [ text "privacy policy" ] ]
                    , a [ class "ui green button", href <| loginUrl model.variables ] [ text "Get Account" ]
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
                    , p [] [ text <| "May works a bit differently from most services. The application will work fine without an account. Getting an account allows you to sync your tasks between your devices, and requires also getting a subscription that costs $3 AUD." ]
                    , p [] [ text "You can cancel your subscription at any time, and you tasks will still be on your devices, they just won't sync anymore." ]
                    , h5 [] [ text "Privacy and Terms of Service" ]
                    , p [] [ text "I value your privacy, feel free to value my ", a [ href "/privacy" ] [ text "privacy policy" ], text ". If you have a subscription with May, you agree to my ", a [ href "/tos" ] [ text "terms of service" ], text "." ]
                    , h5 [] [ text "Contact" ]
                    , p [] [ text "If you have any questions, feature requests or just want to say hi, you can contact Sam Nolan at ", a [ href "mailto:sam@hazelfire.net" ] [ text "sam@hazelfire.net" ] ]
                    ]
                ]

        LocalStorageErrorNotice err ->
            div [ class "help notice" ]
                [ div
                    [ class "noticecontent" ]
                    [ h3 [] [ text "Failed to read local data." ]
                    , p [] [ text "Oh no! I couldn't read the saved tasks and data on your computer" ]
                    , p [] [ text "If you're not a developer, the best you can do is contact ", a [ href "mailto:sam@hazelfire.net" ] [ text "sam@hazelfire.net" ], text " and he can get your data back." ]
                    , p [] [ text "If it doesn't bother you too much. You can also erase all data on your current system" ]
                    , a [ href "/", class "ui red button", onClick DeleteData ] [ text "Delete all data" ]
                    , p [] [ text <| "Here is the error to help find a fix: " ]
                    , code [] [ text err ]
                    ]
                ]


filterJust : List (Maybe a) -> List a
filterJust list =
    case list of
        (Just x) :: rest ->
            x :: filterJust rest

        Nothing :: rest ->
            filterJust rest

        [] ->
            []


filterMaybe : (a -> Maybe b) -> List a -> List b
filterMaybe pred list =
    List.map pred list |> filterJust


type alias UrgencyBarLabeledTask =
    { task : Task
    , start : Time.Posix
    , end : Time.Posix
    , urgency : Float
    , label : Statistics.Label
    , parent : Id Folder
    }


labelTaskToUrgencyBar : Statistics.LabeledTask -> Id Folder -> Statistics.Label -> UrgencyBarLabeledTask
labelTaskToUrgencyBar { task, start, end, urgency } parent label =
    { task = task
    , start = start
    , end = end
    , urgency = urgency
    , parent = parent
    , label = label
    }


labeledTasksToUrgencyBars : FileSystem -> Statistics.LabeledTasks -> List UrgencyBarLabeledTask
labeledTasksToUrgencyBars fs { overdue, doToday, doSoon, doLater, doneToday } =
    let
        tasksWithParents tasks =
            tasks
                |> List.map (\x -> ( x, FileSystem.taskParent (Task.id x.task) fs ))
                |> filterMaybe
                    (\( a, b ) -> Maybe.map (\x -> ( a, x )) b)

        mapToUrgencyBars tasks label =
            List.map (\( task, parent ) -> labelTaskToUrgencyBar task parent label) (tasksWithParents tasks)
    in
    List.concat
        [ mapToUrgencyBars overdue Statistics.Overdue
        , mapToUrgencyBars doneToday Statistics.DoneToday
        , mapToUrgencyBars (List.map Tuple.first doToday) Statistics.DoToday
        , mapToUrgencyBars doSoon Statistics.DoSoon
        , mapToUrgencyBars doLater Statistics.DoLater
        ]


viewStatisticsDetails : Time.Zone -> Time.Posix -> Model -> Maybe Statistics.LabeledTask -> Html Msg
viewStatisticsDetails here now model focusTask =
    let
        tasks =
            Statistics.labelTasks here now (FileSystem.allTasks model.fs)

        diagramTasks =
            tasks.overdue ++ List.map Tuple.first tasks.doToday ++ tasks.doSoon ++ tasks.doLater
    in
    div [ class "notice urgencynotice" ]
        [ h3 [] [ text "Urgency" ]
        , p [] [ text "Urgency represents the amount of hours per day you need to do to complete your tasks by their due dates" ]
        , if List.length diagramTasks > 0 then
            div []
                [ p [] [ text "The following visualises how your urgency is calcualted" ]
                , p [] [ text "Each task is a box, the height of the chart represents your urgency and the right edge of each box represents the due date that we recommend you complete the task by. Grey boxes represent tasks you have completed and the other colours represent the labels you are familiar with." ]
                , p [] [ text "This was the best way that we could organise your tasks making urgency as low as possible. Completing tasks in the first block consist will decrease your urgency, however, doing a task in any later block would not mean you have to do any less work today." ]
                , div [ class "urgencygraphcontainer" ]
                    (filterJust
                        [ Just <| viewGroups here (labeledTasksToUrgencyBars model.fs tasks)
                        , focusTask
                            |> Maybe.map
                                (\t ->
                                    div [ class "urgencylabel" ]
                                        [ p [] [ text <| Task.name t.task ], p [] [ text "Urgency: ", text <| showHours t.urgency ] ]
                                )
                        ]
                    )
                ]

          else
            p [] [ text "You have an urgency of 0 because you do not have any tasks with both a duration larger than 0 and a due date that isn't completed" ]
        ]


viewGroups : Time.Zone -> List UrgencyBarLabeledTask -> Html Msg
viewGroups here tasks =
    let
        firsttask =
            List.head tasks

        maxTime =
            List.maximum (List.map (.task >> Task.due >> Maybe.map Time.posixToMillis >> Maybe.withDefault 0) tasks)
                |> Maybe.map Time.millisToPosix
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
            in
            Svg.svg [ SvgAttr.viewBox 0 0 width height, SvgAttr.class [ "urgencygraph" ], Svg.onMouseLeave (SetUrgencyTaskHover Nothing) ]
                [ Svg.g [ SvgAttr.class [ "axis" ], SvgAttr.transform [ Svg.Translate padding padding ] ]
                    [ Axis.left [ Axis.tickCount 10 ] yscale
                    ]
                , Svg.g [ SvgAttr.class [ "axis" ], SvgAttr.transform [ Svg.Translate padding (height - padding) ] ]
                    [ Axis.bottom [ Axis.tickCount 10 ] xscale
                    ]
                , Svg.g [ SvgAttr.transform [ Svg.Translate padding padding ], SvgAttr.class [ "urgencyboxes" ] ]
                    (List.map (viewUrgencyTaskBar xscale yscale) tasks)
                ]

        _ ->
            div [] []


viewUrgencyTaskBar : Scale.ContinuousScale Time.Posix -> Scale.ContinuousScale Float -> UrgencyBarLabeledTask -> Svg.Svg Msg
viewUrgencyTaskBar xscale yscale { label, parent, urgency, start, end, task } =
    let
        ( max, _ ) =
            Scale.range yscale
    in
    Svg.rect
        [ SvgPx.x (Scale.convert xscale start)
        , SvgPx.y (Scale.convert yscale urgency)
        , SvgPx.width (Scale.convert xscale end - Scale.convert xscale start)
        , SvgPx.height (max - Scale.convert yscale urgency)
        , Svg.onClick (SetView parent)
        , Svg.onMouseEnter (SetUrgencyTaskHover (Just { task = task, start = start, urgency = urgency, end = end }))
        , SvgAttr.class
            [ case label of
                Statistics.DoSoon ->
                    "dosoonbox"

                Statistics.DoLater ->
                    "dolaterbox"

                Statistics.DoToday ->
                    "dotodaybox"

                Statistics.DoneToday ->
                    "donebox"

                Statistics.Overdue ->
                    "overduebox"

                _ ->
                    ""
            , "clickable"
            ]
        ]
        []


viewHeader : Model -> Html Msg
viewHeader model =
    nav [ class "top-menu" ]
        [ li
            [ class
                (if model.notice /= ShowHelp then
                    "active item"

                 else
                    "item clickable"
                )
            , onClick ClearNotices
            ]
            [ text "May" ]
        , li
            [ class
                (if model.notice == ShowHelp then
                    "active item clickable"

                 else
                    "item clickable"
                )
            , onClick
                (if model.notice == ShowHelp then
                    ClearNotices

                 else
                    ShowHelpNotice
                )
            ]
            [ text "Help" ]
        , ul [ class "right" ]
            (let
                showTreeButton =
                    li [ class "item clickable", onClick (ShowTree (not model.showTree)) ]
                        [ text
                            (if model.showTree then
                                "Show Tasks"

                             else
                                "Show Tree"
                            )
                        ]
             in
             [ showTreeButton
             , case model.authState of
                Auth.Authenticated _ ->
                    --[ div [ class "item", onClick ConfirmDeleteAccount ] [ text "Delete Account" ]
                    li [ class "item", onClick Logout ] [ text "Logout" ]

                _ ->
                    a [ class "item loginbutton", href <| loginUrl model.variables ] [ text "Sign in" ]
             ]
            )
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


createTodoItems : FileSystem -> List a -> (a -> Task) -> (a -> String) -> List TodoItem
createTodoItems fs taskSection taskFunc labelFunc =
    filterJust
        (List.map
            (\task ->
                Maybe.map
                    (\parent ->
                        { parent = parent
                        , task = taskFunc task
                        , label = labelFunc task
                        }
                    )
                    (FileSystem.taskParent (Task.id (taskFunc task)) fs)
            )
            taskSection
        )


createTodoSection : FileSystem -> String -> String -> List a -> (a -> Task) -> (a -> String) -> Maybe (Html Msg)
createTodoSection fs color name taskList taskFunc labelFunc =
    case taskList of
        [] ->
            Nothing

        _ ->
            Just (viewTodoSection color name (createTodoItems fs taskList taskFunc labelFunc))


viewTodo : Model -> Html Msg
viewTodo model =
    case ( model.currentZone, model.currentTime ) of
        ( Just here, Just now ) ->
            let
                tasks =
                    FileSystem.allTasks model.fs

                labeledTasks =
                    Statistics.labelTasks here now tasks

                addDurations =
                    Task.duration >> showHours

                addPercentages =
                    Tuple.second >> showPercentage

                addDueDates =
                    \{ end } -> formatTime here end

                doneToday =
                    Statistics.doneToday here now tasks

                id x =
                    x

                fs =
                    model.fs

                sections =
                    [ createTodoSection fs "overdue" "Overdue" labeledTasks.overdue .task (always "")
                    , createTodoSection fs "dotoday" "Do Today" labeledTasks.doToday (Tuple.first >> .task) addPercentages
                    , createTodoSection fs "dosoon" "Do Soon" labeledTasks.doSoon .task addDueDates
                    , createTodoSection fs "dolater" "Do Later" labeledTasks.doLater .task addDueDates
                    , createTodoSection fs "noinfo" "No Info" labeledTasks.noDue id (always "")
                    , createTodoSection fs "done" "Done today" doneToday id addDurations
                    ]

                allSections =
                    filterJust sections
            in
            div [ class "todo" ]
                allSections

        _ ->
            div [] [ text "loading" ]


showPercentage : Float -> String
showPercentage amount =
    String.fromInt (floor (amount * 100)) ++ "%"


type alias TodoItem =
    { task : Task
    , label : String
    , parent : Id Folder
    }


viewTodoSection : String -> String -> List TodoItem -> Html Msg
viewTodoSection color title tasks =
    div []
        (h3 [ class <| "ui header todosectionheader " ++ color ] [ text title ]
            :: List.map
                (\{ task, label, parent } ->
                    div [ class "todoitem" ]
                        [ span [ onClick (SetView parent), class "clickable", tabindex 0 ] [ text <| label ++ " " ++ Task.name task ]
                        ]
                )
                tasks
        )


showHours : Float -> String
showHours float =
    let
        base =
            floor (float * 100)

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


viewStatistics : Time.Zone -> Time.Posix -> List Task -> Html Msg
viewStatistics here now tasks =
    div [ class "ui statistics" ]
        [ viewStatistic ViewUrgency "Done today" (showHours <| List.sum (List.map Task.duration (Statistics.doneToday here now tasks)))
        , viewStatistic ViewUrgency "Urgency" <| (showHours <| Statistics.urgency here now tasks)
        , viewStatistic ViewUrgency "Tomorrow" (showHours <| Statistics.urgency here (tomorrow now) tasks)
        ]


viewStatistic : msg -> String -> String -> Html msg
viewStatistic msg label value =
    div [ class "ui small statistic clickable", onClick msg, tabindex 0 ]
        [ div [ class "value" ] [ text value ]
        , div [ class "label" ] [ text label ]
        ]


viewProgressBar : Time.Zone -> Time.Posix -> List Task -> Html Msg
viewProgressBar here now ts =
    let
        tasks =
            Statistics.labelTasks here now ts

        todo =
            tasks.doneToday ++ tasks.overdue ++ List.map Tuple.first tasks.doToday

        urgency =
            List.sum (List.map (.task >> Task.duration) todo)

        createSegments label =
            List.map
                (\task ->
                    div
                        [ style "width" (String.fromFloat (Task.duration task.task / urgency * 99.9) ++ "%")
                        , class <| "progressbarsegment " ++ labelToColor label
                        ]
                        []
                )
    in
    div [ class "progressbar" ]
        (List.concat
            [ createSegments Statistics.DoneToday tasks.doneToday
            , createSegments Statistics.Overdue tasks.overdue
            , createSegments Statistics.DoToday (List.map Tuple.first tasks.doToday)
            ]
        )


viewButton : String -> String -> msg -> Html msg
viewButton color name message =
    button [ class <| "ui button " ++ color, onClick message ] [ text name ]


confirmDeleteTaskModal : Id Task -> Html Msg
confirmDeleteTaskModal taskId =
    div [ class "ui active modal" ]
        [ p [] [ text "Are you sure that you want to delete this task?" ]
        , button [ class "ui black deny button", onClick ClearEditing ]
            [ text "Cancel" ]
        , button [ class "ui positive button", onClick (DeleteTask taskId) ] [ text "Delete" ]
        ]


confirmDeleteFolderModal : Id Folder -> Html Msg
confirmDeleteFolderModal folderId =
    div [ class "ui active modal" ]
        [ p [] [ text "Are you sure that you want to delete this folder?" ]
        , button [ class "ui black deny button", onClick ClearEditing ]
            [ text "Cancel" ]
        , button [ class "ui positive button", onClick (DeleteFolder folderId) ] [ text "Delete" ]
        ]


moveTaskModal : Id Task -> FileSystem -> Html Msg
moveTaskModal taskId fs =
    div [ class "ui modal active" ]
        [ i [ class "icon red right floated close clickable", onClick ClearEditing ] []
        , div [ class "header" ] [ text "Move Task to?" ]
        , div [ class "content" ]
            [ div [ class "ui list" ]
                [ folderList (Folder.id >> MoveTask taskId) (Folder.new Id.rootId "My Tasks") Nothing fs ]
            ]
        ]


moveFolderModal : Id Folder -> FileSystem -> Html Msg
moveFolderModal folderId fs =
    div [ class "ui modal active" ]
        [ i [ class "icon red right floated close clickable", onClick ClearEditing ] []
        , div [ class "header" ] [ text "Move Folder" ]
        , div [ class "content" ]
            [ div [ class "folderlist" ]
                [ folderList (Folder.id >> MoveFolder folderId) (Folder.new Id.rootId "My Tasks") (Just folderId) fs ]
            ]
        ]


folderList : (Folder -> Msg) -> Folder -> Maybe (Id Folder) -> FileSystem -> Html Msg
folderList cmd folder excluding fs =
    let
        children =
            FileSystem.foldersInFolder (Folder.id folder) fs

        childrenElements =
            children
                |> List.filter (\child -> Just (Folder.id child) /= excluding)
                |> List.map (\child -> folderList cmd child excluding fs)
    in
    div [ class "item" ]
        [ viewIcon "foldericon"
        , span [ class "clickable", onClick (cmd folder) ] [ text <| Folder.name folder ]
        , div [ class "folderlist" ] childrenElements
        ]


viewFolderDetails : String -> Time.Zone -> Time.Posix -> FolderView -> FileSystem -> Html Msg
viewFolderDetails offset here time folderView fs =
    let
        folderId =
            folderView.id

        editingName =
            case folderView.editing of
                EditingFolderName _ ->
                    True

                _ ->
                    False

        isRoot =
            folderId == Id.rootId

        folderM =
            case FileSystem.getFolder folderId fs of
                Just folder ->
                    Just folder

                Nothing ->
                    if isRoot then
                        Just <| Folder.new folderId "My Tasks"

                    else
                        Nothing
    in
    case folderM of
        Just folder ->
            let
                nameText =
                    case folderView.editing of
                        EditingFolderName name ->
                            name

                        _ ->
                            Folder.name folder

                screenmask =
                    div [ class "screenmask", onClick ClearEditing ] []
            in
            div []
                ((case folderView.editing of
                    ConfirmingDeleteFolder fid ->
                        [ screenmask, confirmDeleteFolderModal fid ]

                    MovingFolder childId ->
                        [ screenmask, moveFolderModal childId fs ]

                    _ ->
                        case folderView.taskEdit of
                            Just { id, editing } ->
                                case editing of
                                    ConfirmingDeleteTask ->
                                        [ screenmask, confirmDeleteTaskModal id ]

                                    MovingTask ->
                                        [ screenmask, moveTaskModal id fs ]

                                    _ ->
                                        []

                            _ ->
                                []
                 )
                    ++ [ ul [ class "breadcrumbs" ]
                            (if isRoot then
                                [ li [ class "breadcrumb" ] [ text "My Tasks" ]
                                ]

                             else
                                [ li [ class "item header-name" ]
                                    [ div [ class "breadcrumb" ] [ div [ class "" ] (viewBreadcrumbSections folderView.draggingOver fs folderId) ]
                                    , editableField editingName "foldername" nameText (StartEditingFolderName nameText) ChangeFolderName (restrictMessage (\x -> String.length x > 0) (SetFolderName folderId))
                                    ]
                                ]
                            )

                       -- , div [ class "ui segment attached" ]
                       --     [ viewCheckbox "Share folder" (Folder.isSharing folder) (ShareFolder (Folder.id folder) (not <| Folder.isSharing folder)) "" ]
                       , viewCheckbox "View old tasks" folderView.viewOld (SetViewOld (not folderView.viewOld)) ""
                       , viewFolderList here time folderView.draggingOver folderId fs
                       , viewTaskList offset here time folderId fs folderView
                       , viewButton "addtask right floated primary" "Add Task" (CreateTask folderId)
                       , viewButton "addfolder right floated primary" "Add Folder" (CreateFolder folderId)
                       ]
                )

        Nothing ->
            div [ class "ui header attached top" ] [ text "Could not find folder" ]


viewCheckbox : String -> Bool -> a -> String -> Html a
viewCheckbox labelText state msg className =
    div [ class <| "ui read-only checkbox " ++ className ] [ input [ type_ "checkbox", checked state, onClick msg ] [], label [] [ text labelText ] ]


parseDate : String -> String -> Maybe Time.Posix
parseDate offset date =
    Iso8601.toTime
        (date
            ++ "T23:59:59"
            ++ offset
        )
        |> Result.toMaybe


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


editableNumberField : Bool -> String -> String -> Msg -> (String -> Msg) -> (String -> Msg) -> Html Msg
editableNumberField editing elementId numberValue currentlyEditingMsg workingMsg setValue =
    span [ class "autoexpand" ]
        [ span [ class "autoexpandwidth" ] [ text numberValue ]
        , input
            [ id
                (if editing then
                    elementId

                 else
                    ""
                )
            , onBlur (setValue numberValue)
            , onEnter (setValue numberValue)
            , novalidate True
            , onInput workingMsg
            , onClick currentlyEditingMsg
            , class <|
                "clickable editablefield "
                    ++ elementId
                    ++ (if editing then
                            " editing"

                        else
                            ""
                       )
            , tabindex 0
            , onFocus currentlyEditingMsg
            , value numberValue
            , type_ "number"
            ]
            []
        ]


escapeString : String -> String
escapeString text =
    String.replace " " "\u{00A0}" text


editableField : Bool -> String -> String -> Msg -> (String -> Msg) -> (String -> Msg) -> Html Msg
editableField editing elementId name currentlyEditingMsg workingMsg setValue =
    span [ class "autoexpand" ]
        [ span [ class "autoexpandwidth" ]
            [ text
                << escapeString
              <|
                if name == "" then
                    " "

                else
                    name
            ]
        , input
            [ id
                (if editing then
                    elementId

                 else
                    ""
                )
            , onBlur (setValue name)
            , onEnter (setValue name)
            , onInput workingMsg
            , onClick currentlyEditingMsg
            , class <|
                "clickable editablefield "
                    ++ (if editing then
                            " editing"

                        else
                            ""
                       )
            , tabindex 0
            , onFocus currentlyEditingMsg
            , value name
            ]
            []
        ]


viewBreadcrumbSections : Maybe (Id Folder) -> FileSystem -> Id Folder -> List (Html Msg)
viewBreadcrumbSections dropFolder fs folderId =
    let
        createBreadcrumbSection id name =
            [ a
                [ class <|
                    if Just id == dropFolder then
                        "clickable section dropover"

                    else
                        "clickable section"
                , onClick (SetView id)
                , onDragOver (SetDraggingOver (Just id))
                , onDragLeave (SetDraggingOver Nothing)
                , onDrop (DropMoveTask id)
                ]
                [ text name ]
            , div [ class "divider" ] [ text "/" ]
            ]
    in
    case FileSystem.folderParent folderId fs of
        Just parentId ->
            if parentId == Id.rootId then
                createBreadcrumbSection Id.rootId "My Tasks"

            else
                case FileSystem.getFolder parentId fs of
                    Just folder ->
                        viewBreadcrumbSections dropFolder fs parentId ++ createBreadcrumbSection (Folder.id folder) (Folder.name folder)

                    Nothing ->
                        []

        Nothing ->
            []


viewFolderList : Time.Zone -> Time.Posix -> Maybe (Id Folder) -> Id Folder -> FileSystem -> Html Msg
viewFolderList here time dragOverFolder folderId fs =
    let
        childrenFolders =
            FileSystem.foldersInFolder folderId fs

        taskLabels =
            Statistics.labelTasks here time (FileSystem.allTasks fs)

        labeledFolders =
            List.reverse <| List.map (\folder -> ( folder, Statistics.folderLabelWithId taskLabels (Folder.id folder) fs )) childrenFolders
    in
    viewCards (List.map (\( folder, label ) -> viewFolderCard dragOverFolder label folder) labeledFolders)


viewTaskList : String -> Time.Zone -> Time.Posix -> Id Folder -> FileSystem -> FolderView -> Html Msg
viewTaskList offset here time folderId fs folderView =
    let
        childrenTasks =
            FileSystem.tasksInFolder folderId fs

        filteredTasks =
            if not folderView.viewOld then
                Statistics.doneTodayAndLater here time childrenTasks

            else
                childrenTasks

        taskLabels =
            Statistics.labelTasks here time (FileSystem.allTasks fs)

        labeledTasks =
            List.map (\task -> ( task, Statistics.taskLabelWithId taskLabels (Task.id task) )) filteredTasks
    in
    viewCards (List.map (\( task, label ) -> viewTaskCard offset here time label task folderView.taskEdit) (List.reverse labeledTasks))


viewCards : List (Html Msg) -> Html Msg
viewCards cards =
    div [ class "tasks" ] cards


viewIcon : String -> Html msg
viewIcon icon =
    i [ class <| "icon " ++ icon ] []


labelToColor : Statistics.Label -> String
labelToColor label =
    case label of
        Statistics.Overdue ->
            "overdue"

        Statistics.DoToday ->
            "dotoday"

        Statistics.DoSoon ->
            "dosoon"

        Statistics.DoLater ->
            "dolater"

        Statistics.NoDue ->
            "noinfo"

        Statistics.Done ->
            "done"

        Statistics.DoneToday ->
            "done"


viewFolderCard : Maybe (Id Folder) -> Statistics.Label -> Folder -> Html Msg
viewFolderCard dragOverFolder label folder =
    div
        [ class <|
            if dragOverFolder == Just (Folder.id folder) then
                "folder dropover"

            else
                "folder"
        , onDragStart (StartDrag (FolderId (Folder.id folder)))
        , onDragOver EndDrag
        , onDragOver (SetDraggingOver (Just (Folder.id folder)))
        , onDragLeave (SetDraggingOver Nothing)
        , onDrop (DropMoveTask (Folder.id folder))
        , draggable "true"
        ]
        [ viewIcon <| "foldericon " ++ labelToColor label
        , div
            [ class "foldername clickable"
            , onClick (SetView (Folder.id folder))
            ]
            [ text (Folder.name folder) ]
        , div [ class "icon trash delete clickable", onClick (ConfirmDeleteFolder (Folder.id folder)) ] []
        ]


onDragStart : msg -> Attribute msg
onDragStart msg =
    on "dragstart" <|
        D.succeed msg


onDragLeave : msg -> Attribute msg
onDragLeave msg =
    on "dragleave" <|
        D.succeed msg


onDragEnd : msg -> Attribute msg
onDragEnd msg =
    on "dragend" <|
        D.succeed msg


onDragOver : msg -> Attribute msg
onDragOver msg =
    preventDefaultOn "dragover" <|
        D.succeed ( msg, True )


onDrop : msg -> Attribute msg
onDrop msg =
    preventDefaultOn "drop" <|
        D.succeed ( msg, True )


viewTaskCard : String -> Time.Zone -> Time.Posix -> Statistics.Label -> Task -> Maybe TaskView -> Html Msg
viewTaskCard offset zone now taskLabel task taskViewM =
    let
        checkbox =
            case Task.doneOn task of
                Nothing ->
                    viewCheckbox "" False (SetTaskDoneOn (Task.id task) (Just now)) "donecheckbox"

                Just _ ->
                    viewCheckbox "" True (SetTaskDoneOn (Task.id task) Nothing) "donecheckbox"

        ( nameText, editingName ) =
            Maybe.withDefault ( Task.name task, False ) <|
                case taskViewM of
                    Just taskView ->
                        case taskView.editing of
                            EditingTaskName name ->
                                if taskView.id == Task.id task then
                                    Just ( name, True )

                                else
                                    Nothing

                            _ ->
                                Nothing

                    _ ->
                        Nothing

        ( durationText, editingDuration ) =
            Maybe.withDefault ( String.fromFloat (Task.duration task), False ) <|
                case taskViewM of
                    Just taskView ->
                        case taskView.editing of
                            EditingTaskDuration duration ->
                                if taskView.id == Task.id task then
                                    Just ( duration, True )

                                else
                                    Nothing

                            _ ->
                                Nothing

                    _ ->
                        Nothing

        noDuration =
            Task.duration task == 0 && not editingDuration

        taskId =
            Task.id task
    in
    div [ class <| "task " ++ labelToColor taskLabel, draggable "true", onDragStart (StartDrag (TaskId taskId)), onDragEnd EndDrag ]
        [ checkbox
        , viewIcon <| "tasks " ++ labelToColor taskLabel
        , div [ class "taskname" ]
            [ editableField editingName "taskname" nameText (StartEditingTaskName taskId nameText) ChangeTaskName (restrictMessage (\x -> String.length x > 0) (SetTaskName taskId))
            ]
        , div [ class "taskduration" ]
            [ if noDuration then
                span [ onClick (StartEditingTaskDuration taskId durationText) ] [ text "No Duration" ]

              else
                span []
                    [ editableNumberField editingDuration "taskduration" durationText (StartEditingTaskDuration taskId durationText) (ChangeTaskDuration taskId) (parseFloatMessage (SetTaskDuration taskId))
                    , text " hours"
                    ]
            ]
        , viewDueField offset zone task
        , div [ class "delete icon trash clickable", onClick (DeleteTask taskId) ] []
        ]


viewDueField : String -> Time.Zone -> Task -> Html Msg
viewDueField offset zone task =
    case Task.due task of
        Just dueDate ->
            div [ class "taskdue" ]
                [ input [ required True, type_ "date", value (Date.toIsoString (Date.fromPosix zone dueDate)), onInput (restrictMessageMaybe (parseDate offset >> Maybe.map Just) (SetTaskDue (Task.id task))) ] []
                , span [ class "clickable icon cross", onClick (SetTaskDue (Task.id task) Nothing) ] []
                ]

        Nothing ->
            div [ class "taskdue" ]
                [ span [ class "clickable", onClick (SetTaskDueNow <| Task.id task) ] [ text "No Due Date" ]
                ]
