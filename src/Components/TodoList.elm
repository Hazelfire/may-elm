module Components.TodoList exposing (main)

import Browser
import Html exposing (Attribute, Html, a, button, div, h2, h3, i, input, span, text)
import Html.Attributes exposing (autofocus, class, value)
import Html.Events exposing (keyCode, on, onBlur, onClick, onInput)
import Json.Decode as Json
import May.Folder as Folder
import May.FolderId as FolderId
import May.FolderList as FolderList
import May.Task as Task
import May.TaskBrowser as TaskBrowser
import May.TaskId as TaskId
import May.TaskList as TaskList
import Random


type Model
    = Loading
    | Ready ReadyModel


type alias ReadyModel =
    { tasks : TaskList.TaskList
    , folders : FolderList.FolderList
    , ui : TaskBrowser.TaskBrowser
    }


type TaskView
    = TaskView { currentTask : TaskId.TaskId }


newTaskView : TaskId.TaskId -> TaskView
newTaskView taskId =
    TaskView { currentTask = taskId }


currentTaskView : TaskView -> TaskId.TaskId
currentTaskView (TaskView taskView) =
    taskView.currentTask


type Msg
    = NewFolder Folder.Folder
    | NewTask Task.Task
    | CreateFolder FolderId.FolderId
    | CreateTask FolderId.FolderId
    | SetView TaskBrowser.ItemId
    | DeleteItem TaskBrowser.ItemId
    | ConfirmDelete
    | CloseConfirmDelete
    | StartEditName
    | SetName TaskBrowser.ItemId String
    | ChangeName TaskBrowser.ItemId String
    | EditKeyDown TaskBrowser.ItemId String Int
    | CreateRootFolder Folder.Folder


type alias Label =
    { name : String
    , color : String
    }


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


{-| Initialises from storage modal
-}
init : () -> ( Model, Cmd Msg )
init _ =
    ( Loading, Random.generate CreateRootFolder Folder.generateRoot )


pure : a -> ( a, Cmd msg )
pure model =
    ( model, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case model of
        Loading ->
            case message of
                CreateRootFolder rootFolder ->
                    pure <|
                        Ready
                            { tasks = TaskList.new
                            , folders = FolderList.new [ rootFolder ]
                            , ui = TaskBrowser.new (TaskBrowser.ItemIdFolder (Folder.id rootFolder))
                            }

                _ ->
                    pure <| model

        Ready readyModel ->
            let
                ( newModel, msg ) =
                    updateReady message readyModel
            in
            ( Ready newModel, msg )


{-| Handles the messages after the page has loaded
-}
updateReady : Msg -> ReadyModel -> ( ReadyModel, Cmd Msg )
updateReady msg model =
    let
        browser =
            model.ui
    in
    case msg of
        DeleteItem id ->
            pure <| deleteItem id model

        ConfirmDelete ->
            pure <| { model | ui = TaskBrowser.confirmDelete browser }

        CloseConfirmDelete ->
            pure <| { model | ui = TaskBrowser.closeConfirmDelete browser }

        SetView viewId ->
            pure <| { model | ui = TaskBrowser.new viewId }

        NewFolder newFolder ->
            pure <| { model | folders = FolderList.addFolder model.folders newFolder, ui = TaskBrowser.new (TaskBrowser.ItemIdFolder (Folder.id newFolder)) }

        NewTask newTask ->
            pure <| { model | ui = TaskBrowser.new (TaskBrowser.ItemIdTask (Task.id newTask)), tasks = TaskList.addTask model.tasks newTask }

        StartEditName ->
            pure <| { model | ui = TaskBrowser.editName browser "" }

        ChangeName _ name ->
            pure <| { model | ui = TaskBrowser.editName browser name }

        SetName id name ->
            pure <| { model | folders = FolderList.setFolderName model.folders id name, ui = TaskBrowser.finishEditName browser }

        EditKeyDown id name key ->
            pure <|
                if key == 13 then
                    { model | folders = FolderList.setFolderName model.folders id name, ui = TaskBrowser.finishEditName browser }

                else
                    model

        CreateFolder parentId ->
            ( model, Random.generate NewFolder (Folder.generate parentId) )

        CreateTask parentId ->
            ( model, Random.generate NewTask (Task.generate parentId) )

        _ ->
            pure model


deleteItem : TaskBrowser.ItemId -> ReadyModel -> ReadyModel
deleteItem id model =
    let
        newModel =
            case id of
                TaskBrowser.ItemIdFolder fid ->
                    { model | folders = FolderList.delete model.folders fid }

                TaskBrowser.ItemIdTask tid ->
                    { model | folders = TaskList.delete model.folders tid }
    in
    if id == TaskBrowser.currentView model.ui then
        case FolderList.getParent model.folders (TaskBrowser.currentView model.ui) of
            Just parentId ->
                { newModel | ui = TaskBrowser.new (TaskBrowser.ItemIdFolder parentId) }

            _ ->
                newModel

    else
        newModel


updateRandom : Msg -> Model -> ( Model, Cmd Msg )
updateRandom message model =
    case message of
        _ ->
            ( model, Cmd.none )


{-| Updates a product with a given name by a function
-}
conditionalMap : (a -> Bool) -> (a -> a) -> List a -> List a
conditionalMap cond func list =
    List.map
        (\x ->
            if cond x then
                func x

            else
                x
        )
        list


onKeyDown : (Int -> msg) -> Attribute msg
onKeyDown tagger =
    on "keydown" (Json.map tagger keyCode)


view : Model -> Html Msg
view model =
    case model of
        Loading ->
            div [] [ text "loading" ]

        Ready readyModel ->
            viewReady readyModel


viewReady : ReadyModel -> Html Msg
viewReady readyModel =
    case TaskBrowser.currentView readyModel.ui of
        TaskBrowser.ItemIdFolder folderId ->
            div []
                [ viewHeader readyModel
                , viewFolderDetails readyModel.folders readyModel.tasks folderId
                ]

        TaskBrowser.ItemIdTask taskId ->
            div []
                [ viewHeader readyModel
                , viewTaskDetails readyModel.folders readyModel.tasks taskId
                ]


viewModal : TaskBrowser.TaskBrowser -> Html Msg
viewModal browser =
    if TaskBrowser.isConfirmDelete browser then
        [ viewConfirmDelete (TaskBrowser.currentView browser) ]

    else
        []


viewHeader : ReadyModel -> Html Msg
viewHeader model =
    let
        currentViewId =
            TaskBrowser.currentView model.ui

        parentId =
            parentOf model (TaskBrowser.currentView model.ui)

        name =
            Maybe.withDefault "Missing" <|
                case currentViewId of
                    TaskBrowser.ItemIdFolder folderId ->
                        Maybe.map .name FolderList.folderWithId model.folders folderId

                    TaskBrowser.ItemIdTask taskId ->
                        Maybe.map .name TaskList.taskWithId model.tasks taskId
    in
    [ h2 [ class "ui menu attached top" ]
        ((case parentId of
            Just pid ->
                [ viewBackButton pid ]

            Nothing ->
                []
         )
            ++ (viewTitle name currentViewId
                    :: (case parentId of
                            Just _ ->
                                [ div [ class "right menu" ] [ a [ class "item", onClick ConfirmDelete ] [ text "Delete" ] ] ]

                            Nothing ->
                                []
                       )
               )
        )
    ]


parentOf : ReadyModel -> TaskBrowser.ItemId -> Maybe TaskBrowser.ItemId
parentOf model id =
    TaskBrowser.ItemIdFolder <|
        case id of
            TaskBrowser.ItemIdFolder folderId ->
                FolderList.folderWithId model.folders folderId |> Maybe.andThen Folder.parentId

            TaskBrowser.ItemIdTask taskId ->
                Maybe.map Task.parent (TaskList.taskWithId model.tasks taskId)


viewFolderDetails : FolderList.FolderList -> TaskList.TaskList -> FolderId.FolderId -> Html Msg
viewFolderDetails folders tasks folderId =
    let
        foldersInDirectory =
            FolderList.foldersInFolder folders folderId

        tasksInDirectory =
            TaskList.tasksInFolder tasks folderId

        currentFolder =
            FolderList.folderWithId folders folderId

        parentId =
            FolderList.getParent folders folderId
    in
    div [ class "ui segment attached" ]
        [ div [ class "ui segment attached" ]
            [ h3 [ class "ui header aligned left" ] [ text "Folders", button [ class "ui button", onClick (CreateFolder folderId) ] [ text "Add" ] ]
            , div [ class "ui cards" ] (List.map (Folder.view SetView) foldersInDirectory)
            ]
        , div [ class "ui segment attached" ]
            [ h3 [ class "ui header aligned left" ] [ text "Tasks", button [ class "ui button", onClick (CreateTask folderId) ] [ text "Add" ] ]
            , div [ class "ui cards" ] (List.map viewTask tasksInDirectory)
            ]
        ]


viewTaskDetails : FolderList.FolderList -> TaskList.TaskList -> TaskView -> Html Msg
viewTaskDetails folders tasks model =
    let
        taskM =
            TaskList.taskWithId tasks (currentTaskView model)

        parentM =
            taskM |> Maybe.andThen (Task.parent >> FolderList.folderWithId folders)
    in
    case taskM of
        Just task ->
            div []
                [ div [ class "ui menu attached top" ]
                    [ viewBackButton (Task.parent task)
                    , div [ class "item" ]
                        [ text (Task.name task) ]
                    , div
                        [ class "right menu" ]
                        [ a [ class "item", onClick ConfirmDelete ] [ text "Delete" ]
                        ]
                    ]
                , div [ class "ui segment attached" ]
                    [ div [ class "taskproperty" ]
                        [ span [ class "propertytitle" ] [ text "Duration: " ]
                        , span [ class "propertyvalue" ] [ text <| String.fromFloat (Task.duration task) ]
                        ]
                    , div [ class "taskproperty" ]
                        [ span [ class "propertytitle" ] [ text "In Folder: " ]
                        , span [ class "propertyvalue" ]
                            [ text <|
                                case parentM of
                                    Just parent ->
                                        Folder.name parent

                                    Nothing ->
                                        "No Folder"
                            ]
                        ]
                    ]
                ]

        Nothing ->
            div [] [ text "Invalid task" ]


viewBackButton : FolderId.FolderId -> Html Msg
viewBackButton pid =
    a [ class "item", onClick (SetView pid) ] [ text "Back" ]


viewTask : Task.Task -> Html Msg
viewTask task =
    a [ class "card", onClick (SetView (Task.id task)) ]
        [ div [ class "content" ]
            [ div [ class "header" ]
                [ i [ class "icon tasks" ] []
                , text (Task.name task)
                ]
            ]
        ]


viewConfirmDelete : FolderId.FolderId -> Int -> Html Msg
viewConfirmDelete folderId taskCount =
    div [ class "ui active modal" ]
        [ div [ class "header" ] [ text "Confirm Delete" ]
        , div [ class "content" ] [ text <| "Are you sure you want to delete this folder? It has " ++ String.fromInt taskCount ++ " tasks in it that will get deleted" ]
        , div [ class "actions" ]
            [ div [ class "ui button green", onClick CloseConfirmDelete ] [ text "No" ]
            , div [ class "ui button red cancel", onClick (DeleteItem folderId) ] [ text "Yes" ]
            ]
        ]


viewTitle : String -> TaskBrowser.TaskBrowser -> Html Msg
viewTitle name browser =
    let
        workingName =
            TaskBrowser.workingName browser

        viewId =
            TaskBrowser.currentView browser
    in
    if TaskBrowser.isEditingName browser then
        div [ class "item ui input" ]
            [ input
                [ autofocus True
                , value workingName
                , onKeyDown (EditKeyDown viewId workingName)
                , onInput (ChangeName viewId)
                , onBlur (SetName viewId workingName)
                ]
                []
            ]

    else
        h2 [ class "item ui header", onClick StartEditName ] [ text name ]


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
