module Components.TodoList exposing (main)

import Browser
import Html exposing (Attribute, Html, a, button, div, h2, h3, i, input, text)
import Html.Attributes exposing (autofocus, class, value)
import Html.Events exposing (keyCode, on, onBlur, onClick, onInput)
import Json.Decode as Json
import May.Folder as Folder
import May.FolderId as FolderId
import May.FolderList as FolderList
import May.FolderView as FolderView
import May.Task as Task
import May.TaskId as TaskId
import Random


type Model
    = Loading
    | Ready ReadyModel


type alias ReadyModel =
    { tasks : List Task.Task
    , folders : FolderList.FolderList
    , ui : UIModel
    }


type UIModel
    = ShowingFolder FolderView.FolderView
    | ShowingTask TaskView


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
    | SetFolder FolderId.FolderId
    | DeleteFolder FolderId.FolderId
    | ConfirmDeleteFolder
    | CloseConfirmDelete
    | OpenTask TaskId.TaskId
    | StartEditFolderName
    | SetFolderName FolderId.FolderId String
    | ChangeName FolderId.FolderId String
    | EditKeyDown FolderId.FolderId String Int
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
                            { tasks = []
                            , folders = FolderList.new [ rootFolder ]
                            , ui = ShowingFolder (FolderView.new (Folder.id rootFolder))
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
    case model.ui of
        ShowingFolder folderModel ->
            case msg of
                DeleteFolder id ->
                    pure <| deleteFolder id model

                ConfirmDeleteFolder ->
                    pure <| { model | ui = ShowingFolder (FolderView.confirmDelete folderModel) }

                CloseConfirmDelete ->
                    pure <| { model | ui = ShowingFolder (FolderView.closeConfirmDelete folderModel) }

                SetFolder folderId ->
                    pure <| { model | ui = ShowingFolder (FolderView.new folderId) }

                NewFolder newFolder ->
                    pure <| { model | folders = FolderList.addFolder model.folders newFolder, ui = ShowingFolder (FolderView.new (Folder.id newFolder)) }

                NewTask newTask ->
                    pure <| { model | ui = ShowingTask (newTaskView (Task.id newTask)), tasks = newTask :: model.tasks }

                StartEditFolderName ->
                    pure <| { model | ui = ShowingFolder (FolderView.editFolderName folderModel "") }

                ChangeName _ name ->
                    pure <| { model | ui = ShowingFolder (FolderView.editFolderName folderModel name) }

                SetFolderName id name ->
                    pure <| { model | folders = FolderList.setFolderName model.folders id name, ui = ShowingFolder (FolderView.finishEditFolderName folderModel) }

                EditKeyDown id name key ->
                    pure <|
                        if key == 13 then
                            { model | folders = FolderList.setFolderName model.folders id name, ui = ShowingFolder (FolderView.finishEditFolderName folderModel) }

                        else
                            model

                CreateFolder parentId ->
                    ( model, Random.generate NewFolder (Folder.generate parentId) )

                CreateTask parentId ->
                    ( model, Random.generate NewTask (Task.generate parentId) )

                _ ->
                    pure model

        ShowingTask taskModel ->
            pure model


deleteFolder : FolderId.FolderId -> ReadyModel -> ReadyModel
deleteFolder id model =
    let
        newModel =
            { model | folders = FolderList.delete model.folders id }
    in
    case newModel.ui of
        ShowingFolder folderModel ->
            if id == FolderView.currentFolder folderModel then
                case FolderList.getParent model.folders (FolderView.currentFolder folderModel) of
                    Just parentId ->
                        { newModel | ui = ShowingFolder (FolderView.new parentId) }

                    _ ->
                        newModel

            else
                newModel

        _ ->
            newModel


getTaskById : List Task.Task -> TaskId.TaskId -> Maybe Task.Task
getTaskById tasks id =
    case List.filter (Task.id >> (==) id) tasks of
        x :: _ ->
            Just x

        _ ->
            Nothing


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
    case readyModel.ui of
        ShowingFolder folderModel ->
            viewFolderDetails readyModel.folders readyModel.tasks folderModel

        ShowingTask taskModel ->
            viewTaskDetails readyModel.tasks taskModel


viewFolderDetails : FolderList.FolderList -> List Task.Task -> FolderView.FolderView -> Html Msg
viewFolderDetails folders tasks model =
    let
        currentFolderId =
            FolderView.currentFolder model

        foldersInDirectory =
            FolderList.foldersInFolder folders currentFolderId

        tasksInDirectory =
            FolderList.tasksInFolder tasks currentFolderId

        currentFolder =
            FolderList.folderWithId folders currentFolderId

        parentId =
            FolderList.getParent folders currentFolderId
    in
    div []
        ([ h2 [ class "ui menu attached top" ]
            ((case parentId of
                Just pid ->
                    [ a [ class "item", onClick (SetFolder pid) ] [ text "Back" ] ]

                Nothing ->
                    []
             )
                ++ ((case currentFolder of
                        Just x ->
                            viewFolderHeader x model

                        Nothing ->
                            div [] []
                    )
                        :: (case parentId of
                                Just _ ->
                                    [ div [ class "right menu" ] [ a [ class "item", onClick ConfirmDeleteFolder ] [ text "Delete" ] ] ]

                                Nothing ->
                                    []
                           )
                   )
            )
         , div [ class "ui segment attached" ]
            [ h3 [ class "ui header aligned left" ] [ text "Folders", button [ class "ui button", onClick (CreateFolder (FolderView.currentFolder model)) ] [ text "Add" ] ]
            , div [ class "ui cards" ] (List.map (Folder.view SetFolder) foldersInDirectory)
            ]
         , div [ class "ui segment attached" ]
            [ h3 [ class "ui header aligned left" ] [ text "Tasks", button [ class "ui button", onClick (CreateTask (FolderView.currentFolder model)) ] [ text "Add" ] ]
            , div [ class "ui cards" ] (List.map viewTask tasksInDirectory)
            ]
         ]
            ++ (if FolderView.isConfirmDelete model then
                    [ viewConfirmDelete currentFolderId 1 ]

                else
                    []
               )
        )


viewTaskDetails : List Task.Task -> TaskView -> Html Msg
viewTaskDetails tasks model =
    case getTaskById tasks (currentTaskView model) of
        Just task ->
            div [ class "ui header attached top" ] [ viewBackButton (Task.parent task), text (Task.name task) ]

        Nothing ->
            div [] [ text "Invalid task" ]


viewBackButton : FolderId.FolderId -> Html Msg
viewBackButton pid =
    a [ class "item", onClick (SetFolder pid) ] [ text "Back" ]


viewTask : Task.Task -> Html Msg
viewTask task =
    a [ class "card", onClick (OpenTask (Task.id task)) ]
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
            , div [ class "ui button red cancel", onClick (DeleteFolder folderId) ] [ text "Yes" ]
            ]
        ]


viewFolderHeader : Folder.Folder -> FolderView.FolderView -> Html Msg
viewFolderHeader folder folderView =
    let
        workingName =
            FolderView.workingName folderView

        folderId =
            FolderView.currentFolder folderView
    in
    if FolderView.isEditingName folderView then
        div [ class "item ui input" ]
            [ input
                [ autofocus True
                , value workingName
                , onKeyDown (EditKeyDown folderId workingName)
                , onInput (ChangeName folderId)
                , onBlur (SetFolderName folderId workingName)
                ]
                []
            ]

    else
        h2 [ class "item ui header", onClick StartEditFolderName ] [ text <| Folder.name folder ]


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
