module Components.TodoList exposing (main)

import Browser
import Char
import Components.Folder as F
import Html exposing (Attribute, Html, a, button, div, h2, h3, i, input, text)
import Html.Attributes exposing (autofocus, class, value)
import Html.Events exposing (keyCode, on, onBlur, onClick, onInput)
import Json.Decode as Json
import Random


type alias Model =
    { stored : StoredModel
    , ui : UIModel
    }


type alias UIModel =
    { workingEditField : String
    , confirmDelete : Bool
    , currentViewId : String
    , currentViewType : ItemView
    , editingName : Bool
    }


type ItemView
    = TaskView
    | FolderView


type alias StoredModel =
    { tasks : List Task
    , folders : List F.Folder
    , labels : List Label
    }


type alias Task =
    { id : String
    , name : String
    , duration : Float
    , depedencies : List String
    , labels : List String
    , parent : String
    }


type Msg
    = NewFolder String String
    | NewTask String String
    | CreateFolder String
    | CreateTask String
    | SetFolder String
    | EditFolder EditFolderMsg
    | DeleteFolder String
    | ConfirmDeleteFolder
    | CloseConfirmDelete
    | OpenTask String


type EditFolderMsg
    = StartEditFolderName
    | SetFolderName String String
    | ChangeName String String
    | EditKeyDown String String Int


type alias Label =
    { name : String
    , color : String
    }


main : Program StoredModel Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


{-| Initialises from storage modal
-}
init : StoredModel -> ( Model, Cmd Msg )
init stored =
    ( { stored = stored
      , ui =
            { currentViewId = "root"
            , confirmDelete = False
            , workingEditField = ""
            , currentViewType = FolderView
            , editingName = False
            }
      }
    , Cmd.none
    )


{-| Generates a random id for tasks and folders
-}
generateId : Random.Generator String
generateId =
    Random.map String.fromList (Random.list 100 (Random.map Char.fromCode (Random.int 0 127)))


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    let
        newModel =
            case message of
                EditFolder msg ->
                    updateEditFolderName msg model

                DeleteFolder id ->
                    if id == model.ui.currentViewId then
                        let
                            parentId =
                                (getFolderWithId model.ui.currentViewId model.stored.folders).parent

                            uiModel =
                                model.ui
                        in
                        case parentId of
                            Just pid ->
                                { model | ui = { uiModel | currentViewId = pid } }

                            _ ->
                                model

                    else
                        model

                _ ->
                    model

        storedModel =
            updateStored message newModel.stored

        uiUpdatedModel =
            updateUI message newModel.ui

        ( fullModel, randomCommand ) =
            updateRandom message { model | stored = storedModel, ui = uiUpdatedModel }
    in
    ( fullModel, randomCommand )


updateEditFolderName : EditFolderMsg -> Model -> Model
updateEditFolderName message model =
    let
        uiModel =
            model.ui

        newUiModel =
            case message of
                StartEditFolderName ->
                    { uiModel | editingName = True, workingEditField = (getFolderWithId uiModel.currentViewId model.stored.folders).name }

                ChangeName _ name ->
                    { uiModel | workingEditField = name }

                SetFolderName _ _ ->
                    { uiModel | editingName = False, workingEditField = "" }

                EditKeyDown _ _ key ->
                    if key == 13 then
                        { uiModel | editingName = False, workingEditField = "" }

                    else
                        uiModel
    in
    { model | ui = newUiModel }


getFolderWithId : String -> List F.Folder -> F.Folder
getFolderWithId id folder =
    case List.filter (.id >> (==) id) folder of
        x :: _ ->
            x

        _ ->
            { id = "NULL", name = "Missing Folder", parent = Nothing }


getTaskById : List Task -> String -> Task
getTaskById tasks id =
    case List.filter (.id >> (==) id) tasks of
        x :: _ ->
            x

        _ ->
            { id = "NULL_TASK"
            , name = "Missing Task"
            , duration = 0.0
            , depedencies = []
            , labels = []
            , parent = "root"
            }


setFolderName : String -> String -> List F.Folder -> List F.Folder
setFolderName id name model =
    conditionalMap (.id >> (==) id) (\x -> { x | name = name }) model


{-| This function is all about handling the Smaller UI messages
-}
updateUI : Msg -> UIModel -> UIModel
updateUI message uiModel =
    case message of
        ConfirmDeleteFolder ->
            { uiModel | confirmDelete = True, editingName = False }

        CloseConfirmDelete ->
            { uiModel | confirmDelete = False }

        DeleteFolder _ ->
            { uiModel | confirmDelete = False }

        SetFolder folderId ->
            { uiModel | confirmDelete = False, editingName = False, workingEditField = "", currentViewId = folderId, currentViewType = FolderView }

        NewFolder _ folderId ->
            { uiModel | editingName = True, workingEditField = "New Folder", currentViewId = folderId }

        NewTask _ task ->
            { uiModel | currentViewId = task, editingName = True, currentViewType = TaskView }

        _ ->
            uiModel


updateRandom : Msg -> Model -> ( Model, Cmd Msg )
updateRandom message model =
    case message of
        CreateFolder parentId ->
            ( model, Random.generate (NewFolder parentId) generateId )

        CreateTask parentId ->
            ( model, Random.generate (NewTask parentId) generateId )

        _ ->
            ( model, Cmd.none )


updateStored : Msg -> StoredModel -> StoredModel
updateStored message model =
    case message of
        NewFolder parentId folderId ->
            let
                newFolder =
                    { id = folderId, name = "New Folder", parent = Just parentId }

                newModel =
                    { model | folders = model.folders ++ [ newFolder ] }
            in
            newModel

        NewTask parentId taskId ->
            let
                newTask =
                    { id = taskId
                    , name = "New Task"
                    , parent = parentId
                    , depedencies = []
                    , duration = 0.0
                    , labels = []
                    }

                newModel =
                    { model | tasks = newTask :: model.tasks }
            in
            newModel

        EditFolder (SetFolderName id name) ->
            { model | folders = setFolderName id name model.folders }

        EditFolder (EditKeyDown id name 13) ->
            { model | folders = setFolderName id name model.folders }

        _ ->
            model


{-| String is the id of the folder that you wish to delete
-}
deleteFolder : String -> List F.Folder -> List F.Folder
deleteFolder id folders =
    List.filter (.id >> (/=) id) folders


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


{-| Gets all the folders in a directory
-}
getFoldersInFolder : List F.Folder -> String -> List F.Folder
getFoldersInFolder folders parentId =
    List.filter (.parent >> (==) (Just parentId)) folders


{-| Gets all the folders in a directory recursively
-}
getFoldersInFolderRecursive : List F.Folder -> String -> List F.Folder
getFoldersInFolderRecursive folders parentId =
    let
        subFolders =
            getFoldersInFolder folders parentId

        subFoldersId =
            List.map .id subFolders
    in
    subFolders ++ List.concat (List.map (getFoldersInFolderRecursive folders) subFoldersId)


{-| Gets all the tasks in a directory
-}
getTasksInFolder : List Task -> String -> List Task
getTasksInFolder tasks parentId =
    List.filter (.parent >> (==) parentId) tasks


{-| Gets all the tasks in a directory recursively
-}
getTasksInFolderRecursive : List F.Folder -> List Task -> String -> List Task
getTasksInFolderRecursive folders tasks parentId =
    let
        subTasks =
            getTasksInFolder tasks parentId

        subFolders =
            getFoldersInFolder folders parentId

        subFoldersId =
            List.map .id subFolders
    in
    subTasks ++ List.concat (List.map (getTasksInFolderRecursive folders tasks) subFoldersId)


onKeyDown : (Int -> msg) -> Attribute msg
onKeyDown tagger =
    on "keydown" (Json.map tagger keyCode)


view : Model -> Html Msg
view model =
    case model.ui.currentViewType of
        FolderView ->
            viewFolderDetails model

        TaskView ->
            viewTaskDetails model


viewFolderDetails : Model -> Html Msg
viewFolderDetails model =
    let
        foldersInDirectory =
            getFoldersInFolder model.stored.folders model.ui.currentViewId

        tasksInDirectory =
            getTasksInFolder model.stored.tasks model.ui.currentViewId

        parentId =
            (getFolderWithId model.ui.currentViewId model.stored.folders).parent
    in
    div []
        ([ h2 [ class "ui menu attached top" ]
            ((case parentId of
                Just pid ->
                    [ a [ class "item", onClick (SetFolder pid) ] [ text "Back" ] ]

                Nothing ->
                    []
             )
                ++ (viewFolderHeader EditFolder model
                        :: (case parentId of
                                Just _ ->
                                    [ div [ class "right menu" ] [ a [ class "item", onClick ConfirmDeleteFolder ] [ text "Delete" ] ] ]

                                Nothing ->
                                    []
                           )
                   )
            )
         , div [ class "ui segment attached" ]
            [ h3 [ class "ui header aligned left" ] [ text "Folders", button [ class "ui button", onClick (CreateFolder model.ui.currentViewId) ] [ text "Add" ] ]
            , div [ class "ui cards" ] (List.map (F.viewFolder SetFolder) foldersInDirectory)
            ]
         , div [ class "ui segment attached" ]
            [ h3 [ class "ui header aligned left" ] [ text "Tasks", button [ class "ui button", onClick (CreateTask model.ui.currentViewId) ] [ text "Add" ] ]
            , div [ class "ui cards" ] (List.map viewTask tasksInDirectory)
            ]
         ]
            ++ (if model.ui.confirmDelete then
                    [ viewConfirmDelete model ]

                else
                    []
               )
        )


viewTaskDetails : Model -> Html Msg
viewTaskDetails model =
    let
        currentTask =
            getTaskById model.stored.tasks model.ui.currentViewId
    in
    div [ class "ui header attached top" ] [ viewBackButton currentTask.parent, text currentTask.name ]


viewBackButton : String -> Html Msg
viewBackButton pid =
    a [ class "item", onClick (SetFolder pid) ] [ text "Back" ]


viewTask : Task -> Html Msg
viewTask task =
    a [ class "card", onClick (OpenTask task.id) ]
        [ div [ class "content" ]
            [ div [ class "header" ]
                [ i [ class "icon tasks" ] []
                , text task.name
                ]
            ]
        ]


viewConfirmDelete : Model -> Html Msg
viewConfirmDelete model =
    let
        taskCount =
            List.length (getTasksInFolderRecursive model.stored.folders model.stored.tasks model.ui.currentViewId)
    in
    div [ class "ui active modal" ]
        [ div [ class "header" ] [ text "Confirm Delete" ]
        , div [ class "content" ] [ text <| "Are you sure you want to delete this folder? It has " ++ String.fromInt taskCount ++ " tasks in it that will get deleted" ]
        , div [ class "actions" ]
            [ div [ class "ui button green", onClick CloseConfirmDelete ] [ text "No" ]
            , div [ class "ui button red cancel", onClick (DeleteFolder model.ui.currentViewId) ] [ text "Yes" ]
            ]
        ]


viewFolderHeader : (EditFolderMsg -> a) -> Model -> Html a
viewFolderHeader messageContext model =
    let
        folderId =
            model.ui.currentViewId

        folder =
            getFolderWithId folderId model.stored.folders

        workingFolderName =
            model.ui.workingEditField
    in
    if model.ui.editingName then
        div [ class "item ui input" ] [ input [ autofocus True, value workingFolderName, onKeyDown (EditKeyDown folderId workingFolderName >> messageContext), onInput (ChangeName folderId >> messageContext), onBlur (messageContext (SetFolderName folderId workingFolderName)) ] [] ]

    else
        h2 [ class "item ui header", onClick (messageContext StartEditFolderName) ] [ text folder.name ]


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
