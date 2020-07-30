module TodoListSpec exposing (suite)

import Expect
import Json.Encode as E
import May.FileSystem as FileSystem
import May.Folder as Folder exposing (Folder)
import May.Id as Id exposing (Id)
import May.Task as Task
import Test exposing (..)
import TodoList
import Tuple


rootId : Id Folder
rootId =
    Id.testId "root"


emptyTodoList : TodoList.Model
emptyTodoList =
    Tuple.first <| TodoList.update (TodoList.NewFS rootId) (Tuple.first <| TodoList.init E.null)


applyList : List a -> (a -> b -> b) -> b -> b
applyList actions update init =
    case actions of
        a :: rest ->
            applyList rest update (update a init)

        [] ->
            init


suite : Test
suite =
    describe "TodoList"
        [ describe "Delete Task"
            [ test "shows parent folder when task deleted" <|
                \_ ->
                    let
                        model =
                            emptyTodoList

                        taskId =
                            Id.testId "task"

                        actions =
                            [ TodoList.NewTask rootId taskId
                            , TodoList.SetView (TodoList.ViewIdTask taskId)
                            , TodoList.ConfirmDeleteTask
                            , TodoList.DeleteTask taskId
                            ]

                        newModel =
                            applyList actions (\a -> TodoList.update a >> Tuple.first) model

                        actualViewing =
                            case newModel of
                                TodoList.Ready readyModel ->
                                    Just readyModel.viewing

                                _ ->
                                    Nothing
                    in
                    Expect.equal actualViewing (Just <| TodoList.ViewTypeFolder { id = rootId, editing = TodoList.NotEditingFolder })
            , test "shows parent folder when folder deleted" <|
                \_ ->
                    let
                        model =
                            emptyTodoList

                        folderId =
                            Id.testId "folder"

                        actions =
                            [ TodoList.NewFolder rootId folderId
                            , TodoList.SetView (TodoList.ViewIdFolder folderId)
                            , TodoList.ConfirmDeleteFolder
                            , TodoList.DeleteFolder folderId
                            ]

                        actualModel =
                            applyList actions (\a -> TodoList.update a >> Tuple.first) model

                        expectedModel =
                            TodoList.Ready
                                { currentTime = Nothing
                                , fs = FileSystem.new (Folder.new rootId "My Tasks")
                                , viewing = TodoList.ViewTypeFolder { id = rootId, editing = TodoList.NotEditingFolder }
                                }
                    in
                    Expect.equal actualModel expectedModel
            ]
        ]
