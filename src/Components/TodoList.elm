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
    , editingFolderName : Bool
    , workingFolderName : String
    , confirmDeleteFolder : Bool
    }


type alias StoredModel =
    { tasks : List Task
    , folders : List F.Folder
    , currentFolder : F.Folder
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
    = NewFolder String
    | CreateFolder
    | SetFolder String
    | EditFolder EditFolderMsg
    | DeleteCurrentFolder
    | ConfirmDeleteFolder
    | CloseConfirmDelete
    | OpenTask Task


type EditFolderMsg
    = StartEditFolderName
    | SetFolderName
    | ChangeFolderName String
    | EditKeyDown Int


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
      , editingFolderName = False
      , workingFolderName = ""
      , confirmDeleteFolder = False
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
    case message of
        EditFolder msg ->
            ( updateEditFolderName msg model, Cmd.none )

        _ ->
            let
                storedModel =
                    updateStored message model.stored

                ( fullModel, randomCommand ) =
                    updateRandom message { model | stored = storedModel }
            in
            ( updateUI message fullModel, randomCommand )


updateEditFolderName : EditFolderMsg -> Model -> Model
updateEditFolderName message model =
    case message of
        StartEditFolderName ->
            { model | editingFolderName = True, workingFolderName = model.stored.currentFolder.name }

        ChangeFolderName name ->
            { model | workingFolderName = name }

        SetFolderName ->
            saveFolderName model

        EditKeyDown key ->
            if key == 13 then
                saveFolderName model

            else
                model


saveFolderName : Model -> Model
saveFolderName model =
    let
        newName =
            model.workingFolderName

        storedModel =
            model.stored

        currentFolder =
            model.stored.currentFolder

        newCurrentFolder =
            { currentFolder | name = newName }

        newFolders =
            conditionalMap (.id >> (==) currentFolder.id) (\folder -> { folder | name = newName }) model.stored.folders

        newStoredModal =
            { storedModel | folders = newFolders, currentFolder = newCurrentFolder }
    in
    { model | stored = newStoredModal, editingFolderName = False, workingFolderName = "" }


{-| This function is all about handling the Smaller UI messages
-}
updateUI : Msg -> Model -> Model
updateUI message model =
    case message of
        ConfirmDeleteFolder ->
            { model | confirmDeleteFolder = True, editingFolderName = False }

        CloseConfirmDelete ->
            { model | confirmDeleteFolder = False }

        DeleteCurrentFolder ->
            { model | confirmDeleteFolder = False }

        SetFolder _ ->
            { model | confirmDeleteFolder = False, editingFolderName = False, workingFolderName = "" }

        NewFolder _ ->
            { model | editingFolderName = True, workingFolderName = "New Folder" }

        _ ->
            model


updateRandom : Msg -> Model -> ( Model, Cmd Msg )
updateRandom message model =
    case message of
        CreateFolder ->
            ( model, Random.generate NewFolder generateId )

        _ ->
            ( model, Cmd.none )


updateStored : Msg -> StoredModel -> StoredModel
updateStored message model =
    case message of
        NewFolder folderId ->
            let
                newFolder =
                    { id = folderId, name = "New Folder", parent = Just model.currentFolder.id }

                newModel =
                    { model | folders = model.folders ++ [ newFolder ], currentFolder = newFolder }
            in
            newModel

        SetFolder folderId ->
            let
                parentFolders =
                    List.filter (.id >> (==) folderId) model.folders

                newModel =
                    case parentFolders of
                        x :: _ ->
                            { model | currentFolder = x }

                        _ ->
                            model
            in
            newModel

        DeleteCurrentFolder ->
            deleteCurrentFolder model

        _ ->
            model


deleteCurrentFolder : StoredModel -> StoredModel
deleteCurrentFolder model =
    let
        parentId =
            model.currentFolder.parent

        parentFolders =
            List.filter (.id >> Just >> (==) parentId) model.folders

        newFolders =
            List.filter (.id >> (/=) model.currentFolder.id) model.folders

        newModel =
            case parentFolders of
                x :: _ ->
                    { model | currentFolder = x, folders = newFolders }

                _ ->
                    model
    in
    newModel


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
getFoldersInFolder : List F.Folder -> F.Folder -> List F.Folder
getFoldersInFolder folders parent =
    List.filter (.parent >> (==) (Just parent.id)) folders


{-| Gets all the folders in a directory recursively
-}
getFoldersInFolderRecursive : List F.Folder -> F.Folder -> List F.Folder
getFoldersInFolderRecursive folders parent =
    let
        subFolders =
            getFoldersInFolder folders parent
    in
    subFolders ++ List.concat (List.map (getFoldersInFolderRecursive folders) subFolders)


{-| Gets all the tasks in a directory
-}
getTasksInFolder : List Task -> F.Folder -> List Task
getTasksInFolder tasks parent =
    List.filter (.parent >> (==) parent.id) tasks


{-| Gets all the tasks in a directory recursively
-}
getTasksInFolderRecursive : List F.Folder -> List Task -> F.Folder -> List Task
getTasksInFolderRecursive folders tasks parent =
    let
        subTasks =
            getTasksInFolder tasks parent

        subFolders =
            getFoldersInFolder folders parent
    in
    subTasks ++ List.concat (List.map (getTasksInFolderRecursive folders tasks) subFolders)


onKeyDown : (Int -> msg) -> Attribute msg
onKeyDown tagger =
    on "keydown" (Json.map tagger keyCode)


view : Model -> Html Msg
view model =
    let
        foldersInDirectory =
            getFoldersInFolder model.stored.folders model.stored.currentFolder

        tasksInDirectory =
            getTasksInFolder model.stored.tasks model.stored.currentFolder

        parentId =
            model.stored.currentFolder.parent
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
            [ h3 [ class "ui header aligned left" ] [ text "Folders", button [ class "ui button", onClick CreateFolder ] [ text "Add" ] ]
            , div [ class "ui cards" ] (List.map (F.viewFolder SetFolder) foldersInDirectory)
            ]
         , div [ class "ui segment attached" ]
            [ h3 [ class "ui header aligned left" ] [ text "Tasks", button [ class "ui button", onClick CreateFolder ] [ text "Add" ] ]
            , div [ class "ui cards" ] (List.map viewTask tasksInDirectory)
            ]
         ]
            ++ (if model.confirmDeleteFolder then
                    [ viewConfirmDelete model ]

                else
                    []
               )
        )


viewTask : Task -> Html Msg
viewTask task =
    a [ class "card", onClick (OpenTask task) ]
        [ div [ class "content" ]
            [ div [ class "header" ]
                [ i [ class "icon tasks" ] []
                , text task.name
                ]
            ]
        ]


viewConfirmDelete : Model -> Html Msg
viewConfirmDelete _ =
    div [ class "ui active modal" ]
        [ div [ class "header" ] [ text "Confirm Delete" ]
        , div [ class "content" ] [ text "Are you sure you want to delete this folder?" ]
        , div [ class "actions" ]
            [ div [ class "ui button green", onClick CloseConfirmDelete ] [ text "No" ]
            , div [ class "ui button red cancel", onClick DeleteCurrentFolder ] [ text "Yes" ]
            ]
        ]


viewFolderHeader : (EditFolderMsg -> a) -> Model -> Html a
viewFolderHeader messageContext model =
    if model.editingFolderName then
        div [ class "item ui input" ] [ input [ autofocus True, value model.workingFolderName, onKeyDown (EditKeyDown >> messageContext), onInput (ChangeFolderName >> messageContext), onBlur (messageContext SetFolderName) ] [] ]

    else
        h2 [ class "item ui header", onClick (messageContext StartEditFolderName) ] [ text model.stored.currentFolder.name ]


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
