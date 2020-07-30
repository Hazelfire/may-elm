port module TodoList exposing
    ( FolderEditing(..)
    , Model(..)
    , Msg(..)
    , TaskEditing(..)
    , ViewId(..)
    , ViewType(..)
    , init
    , main
    , update
    )

import Browser
import Date
import Html exposing (Attribute, Html, a, button, div, h3, i, input, label, p, span, text)
import Html.Attributes exposing (checked, class, id, type_, value)
import Html.Events exposing (keyCode, on, onBlur, onClick, onInput)
import Iso8601
import Json.Decode as Json
import Json.Encode as E
import May.FileSystem as FileSystem exposing (FileSystem)
import May.Folder as Folder exposing (Folder)
import May.Id as Id exposing (Id)
import May.Statistics as Statistics
import May.Task as Task exposing (Task)
import Random
import Task
import Time


type Model
    = Loading
    | Ready ReadyModel


type ViewId
    = ViewIdFolder (Id Folder)
    | ViewIdTask (Id Task)


type alias ReadyModel =
    { fs : FileSystem
    , viewing : ViewType
    , currentTime : Maybe Time.Posix
    }


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
    = NewFS (Id Folder)
    | CreateFolder (Id Folder)
    | NewFolder (Id Folder) (Id Folder)
    | CreateTask (Id Folder)
    | NewTask (Id Folder) (Id Task)
    | StartEditingTaskName
    | StartEditingFolderName
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
    | NoOp


main : Program E.Value Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = \_ -> Time.every 5000.0 SetTime
        , view = view
        }


{-| Initialises from storage modal
-}
init : E.Value -> ( Model, Cmd Msg )
init flags =
    case Json.decodeValue FileSystem.decode flags of
        Ok fs ->
            ( Ready
                { fs = fs
                , viewing = ViewTypeFolder { id = FileSystem.getRootId fs, editing = NotEditingFolder }
                , currentTime = Nothing
                }
            , Time.now |> Task.perform SetTime
            )

        Err _ ->
            ( Loading, Random.generate NewFS Id.generate )


pure : a -> ( a, Cmd msg )
pure model =
    ( model, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case model of
        Loading ->
            case message of
                NewFS rootId ->
                    pure <|
                        Ready
                            { fs = FileSystem.new (Folder.new rootId "My Tasks")
                            , viewing = ViewTypeFolder { id = rootId, editing = NotEditingFolder }
                            , currentTime = Nothing
                            }

                _ ->
                    pure model

        Ready readyModel ->
            let
                ( newModel, command ) =
                    updateReady message readyModel
            in
            ( Ready newModel, command )


port setLocalStorage : E.Value -> Cmd msg


port setFocus : String -> Cmd msg


updateReady : Msg -> ReadyModel -> ( ReadyModel, Cmd Msg )
updateReady message model =
    case message of
        CreateFolder parentId ->
            ( model, Random.generate (NewFolder parentId) Id.generate )

        NewFolder parentId id ->
            saveToLocalStorage <| { model | fs = FileSystem.addFolder parentId (Folder.new id "New Folder") model.fs }

        CreateTask parentId ->
            ( model, Random.generate (NewTask parentId) Id.generate )

        NewTask parentId taskId ->
            saveToLocalStorage <| { model | fs = FileSystem.addTask parentId (Task.new taskId "New Task") model.fs }

        SetTime time ->
            pure <| { model | currentTime = Just time }

        SetView vid ->
            case vid of
                ViewIdFolder fid ->
                    pure <| { model | viewing = newFolderView fid }

                ViewIdTask tid ->
                    pure <| { model | viewing = newTaskView tid }

        StartEditingFolderName ->
            withCommand (always (setFocus "foldername")) <| mapViewing (mapFolderView (mapFolderEditing (always (EditingFolderName "")))) model

        StartEditingTaskName ->
            withCommand (always (setFocus "taskname")) <| mapViewing (mapTaskView (mapTaskEditing (always (EditingTaskName "")))) model

        SetFolderName fid name ->
            let
                fsChange =
                    mapFileSystem (FileSystem.mapOnFolder fid (Folder.rename name)) model
            in
            saveToLocalStorage <| mapViewing (mapFolderView (mapFolderEditing (always NotEditingFolder))) fsChange

        SetTaskName tid name ->
            let
                fsChange =
                    mapFileSystem (FileSystem.mapOnTask tid (Task.rename name)) model
            in
            saveToLocalStorage <| mapViewing (mapTaskView (mapTaskEditing (always NotEditingTask))) fsChange

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
            saveToLocalStorage <| mapViewing (mapTaskView (mapTaskEditing (always NotEditingTask))) fsChange

        SetTaskDue tid due ->
            saveToLocalStorage <| mapFileSystem (FileSystem.mapOnTask tid (Task.setDue due)) model

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
                    saveToLocalStorage <| mapViewing (always (newFolderView pid)) fsChange

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
                    saveToLocalStorage <| mapViewing (always (newFolderView pid)) fsChange

                _ ->
                    pure model

        _ ->
            pure model


saveToLocalStorage : ReadyModel -> ( ReadyModel, Cmd msg )
saveToLocalStorage =
    withCommand (\model -> setLocalStorage (FileSystem.encode model.fs))


withCommand : (a -> Cmd msg) -> a -> ( a, Cmd msg )
withCommand commandFunc model =
    ( model, commandFunc model )


addWeek : Time.Posix -> Time.Posix
addWeek time =
    Time.millisToPosix <| Time.posixToMillis time + (1000 * 60 * 60 * 24 * 7)


mapViewing : (ViewType -> ViewType) -> ReadyModel -> ReadyModel
mapViewing func model =
    { model | viewing = func model.viewing }


mapTaskEditing : (TaskEditing -> TaskEditing) -> TaskView -> TaskView
mapTaskEditing func model =
    { model | editing = func model.editing }


mapFolderEditing : (FolderEditing -> FolderEditing) -> FolderView -> FolderView
mapFolderEditing func model =
    { model | editing = func model.editing }


mapFileSystem : (FileSystem -> FileSystem) -> ReadyModel -> ReadyModel
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
    case model of
        Loading ->
            div [] [ text "loading" ]

        Ready readyModel ->
            viewReady readyModel


viewReady : ReadyModel -> Html Msg
viewReady readyModel =
    let
        itemView =
            case readyModel.viewing of
                ViewTypeFolder folderView ->
                    viewFolderDetails folderView readyModel.fs

                ViewTypeTask taskView ->
                    viewTaskDetails taskView readyModel.fs
    in
    div [ class "ui divided stackable grid" ]
        [ div
            [ class "twelve wide column" ]
            [ viewStatistics readyModel.currentTime (FileSystem.allTasks readyModel.fs)
            , itemView
            ]
        , div [ class "four wide column" ] [ viewTodo readyModel.currentTime (FileSystem.allTasks readyModel.fs) ]
        ]


viewTodo : Maybe Time.Posix -> List Task -> Html Msg
viewTodo nowM tasks =
    case nowM of
        Just now ->
            let
                urgencyTasks =
                    List.map (\x -> ( x, Statistics.taskUrgency now x )) tasks

                sortedTasks =
                    List.sortBy (Tuple.second >> negate) urgencyTasks
            in
            div [ class "todo" ]
                (List.map
                    (\( task, urgency ) ->
                        div [ class "todoitem" ]
                            [ a [ onClick (SetView (ViewIdTask (Task.id task))) ] [ text <| showFloat urgency ++ ": " ++ Task.name task ]
                            ]
                    )
                    sortedTasks
                )

        Nothing ->
            div [] [ text "loading" ]


showFloat : Float -> String
showFloat float =
    let
        base =
            round (float * 100)

        beforeDecimal =
            base // 100

        afterDecimal =
            modBy 100 base
    in
    String.fromInt beforeDecimal ++ "." ++ String.fromInt afterDecimal


viewStatistics : Maybe Time.Posix -> List Task -> Html Msg
viewStatistics nowM tasks =
    case nowM of
        Just now ->
            div [ class "ui statistics" ]
                [ viewStatistic "Urgency" (showFloat <| Statistics.urgency now tasks)
                , viewStatistic "Velocity" (showFloat <| Statistics.velocity now tasks)
                , viewStatistic "Bait" (showFloat <| Statistics.bait now tasks)
                ]

        Nothing ->
            div [] [ text "Loading" ]


viewStatistic : String -> String -> Html msg
viewStatistic label value =
    div [ class "ui small statistic" ] [ div [ class "value" ] [ text value ], div [ class "label" ] [ text label ] ]


viewButton : String -> msg -> Html msg
viewButton name message =
    button [ class "ui button", onClick message ] [ text name ]


viewFolderDetails : FolderView -> FileSystem -> Html Msg
viewFolderDetails folderView fs =
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
                            , div [ class "ui positive button", onClick (DeleteFolder folderId) ] [ text "Delete" ]
                            ]
                        ]
                    ]

                  else
                    []
                 )
                    ++ [ div [ class "ui header attached top" ]
                            [ viewBackButton (FileSystem.folderParent folderId fs)
                            , editableField editingName "foldername" nameText StartEditingFolderName ChangeFolderName (restrictMessage (always True) (SetFolderName folderId))
                            , viewButton "Delete" ConfirmDeleteFolder
                            ]
                       , div [ class "ui segment attached" ]
                            [ h3 [ class "ui header" ]
                                [ text "Folders"
                                , viewButton "Add" (CreateFolder folderId)
                                ]
                            , viewFolderList folderId fs
                            ]
                       , div [ class "ui segment attached" ]
                            [ h3 [ class "ui header" ]
                                [ text "Tasks"
                                , viewButton "Add" (CreateTask folderId)
                                ]
                            , viewTaskList folderId fs
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
                    ++ [ div [ class "ui header attached top" ]
                            [ viewBackButton (FileSystem.taskParent taskId fs)
                            , editableField editingName "taskname" nameText StartEditingTaskName ChangeTaskName (restrictMessage (always True) (SetTaskName taskId))
                            , viewButton "Delete" ConfirmDeleteTask
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
    on "keydown" (Json.map (restrictMessage ((==) 13) (always message)) keyCode)


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


mapMaybe : (a -> Maybe b) -> List a -> List b
mapMaybe pred list =
    case list of
        x :: rest ->
            case pred x of
                Just y ->
                    y :: mapMaybe pred rest

                Nothing ->
                    mapMaybe pred rest

        _ ->
            []


viewFolderList : Id Folder -> FileSystem -> Html Msg
viewFolderList folderId fs =
    let
        childrenIds =
            FileSystem.foldersInFolder folderId fs

        childrenFolders =
            mapMaybe (\x -> FileSystem.getFolder x fs) childrenIds
    in
    viewCards (List.map viewFolderCard childrenFolders)


viewTaskList : Id Folder -> FileSystem -> Html Msg
viewTaskList folderId fs =
    let
        childrenIds =
            FileSystem.tasksInFolder folderId fs

        childrenTasks =
            mapMaybe (\x -> FileSystem.getTask x fs) childrenIds
    in
    viewCards (List.map viewTaskCard childrenTasks)


viewCards : List (Html Msg) -> Html Msg
viewCards cards =
    div [ class "ui cards" ] cards


viewIcon : String -> Html msg
viewIcon icon =
    i [ class <| "icon " ++ icon ] []


viewFolderCard : Folder -> Html Msg
viewFolderCard folder =
    a [ class "ui card", onClick (SetView (ViewIdFolder (Folder.id folder))) ]
        [ div [ class "content" ] [ div [ class "header" ] [ viewIcon "folder", text (Folder.name folder) ] ] ]


viewTaskCard : Task -> Html Msg
viewTaskCard task =
    a [ class "ui card", onClick (SetView (ViewIdTask (Task.id task))) ]
        [ div [ class "content" ] [ div [ class "header" ] [ viewIcon "tasks", text (Task.name task) ] ] ]
