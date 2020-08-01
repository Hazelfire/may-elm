module TodoListSpec exposing (suite)

import Expect
import Http
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
    Tuple.first <| TodoList.init E.null


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
                    in
                    Expect.equal newModel.viewing (TodoList.ViewTypeFolder { id = rootId, editing = TodoList.NotEditingFolder })
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
                            { currentTime = Nothing
                            , fs = FileSystem.new (Folder.new rootId "My Tasks")
                            , viewing = TodoList.ViewTypeFolder { id = rootId, editing = TodoList.NotEditingFolder }
                            , authState = TodoList.Unauthenticated
                            }
                    in
                    Expect.equal actualModel expectedModel
            ]
        , describe "Authenticaion"
            [ test "init with token causes loading" <|
                \_ ->
                    let
                        tokenObject =
                            E.object [ ( "code", E.string "test-code" ) ]

                        model =
                            Tuple.first <| TodoList.init tokenObject
                    in
                    Expect.equal (TodoList.Authenticating "test-code") model.authState
            , test "error response creates auth failed" <|
                \_ ->
                    let
                        tokenObject =
                            E.object [ ( "code", E.string "test-code" ) ]

                        model =
                            Tuple.first <| TodoList.init tokenObject

                        newModel =
                            Tuple.first <| TodoList.update (TodoList.GotAuthResponse (Err Http.Timeout)) model
                    in
                    Expect.equal TodoList.AuthFailed newModel.authState
            , test "success response creates subscription check" <|
                \_ ->
                    let
                        tokenObject =
                            E.object [ ( "code", E.string "test-code" ) ]

                        model =
                            Tuple.first <| TodoList.init tokenObject

                        authResponse =
                            { idToken = "", accessToken = "", refreshToken = "", expiresIn = 0 }

                        newModel =
                            Tuple.first <| TodoList.update (TodoList.GotAuthResponse (Ok authResponse)) model
                    in
                    Expect.equal (TodoList.CheckingSubscription authResponse) newModel.authState
            , test "success subscription check returns authenticated" <|
                \_ ->
                    let
                        tokenObject =
                            E.object [ ( "code", E.string "test-code" ) ]

                        model =
                            Tuple.first <| TodoList.init tokenObject

                        newModel =
                            Tuple.first <| TodoList.update (TodoList.GotSubscriptionCheck (Ok True)) model
                    in
                    Expect.equal TodoList.Authenticated newModel.authState
            ]
        ]
