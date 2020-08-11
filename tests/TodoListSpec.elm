module TodoListSpec exposing (suite)

import Expect
import Http
import Json.Decode as D
import Json.Encode as E
import May.FileSystem as FileSystem
import May.Folder as Folder exposing (Folder)
import May.Id as Id exposing (Id)
import Result
import Test exposing (Test, describe, test)
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


{-| This can't actually be Nothing unless there is something seriously wrong
with the way FSUpdate is implemented.
-}
emptyUpdateM : Maybe FileSystem.FSUpdate
emptyUpdateM =
    Result.toMaybe <| D.decodeValue FileSystem.fsUpdateDecoder (E.list (\x -> x) [])


authenticatedModel : TodoList.Model
authenticatedModel =
    let
        tokenObject =
            E.object [ ( "code", E.string "test-code" ) ]

        model =
            Tuple.first <| TodoList.init tokenObject

        authResponse =
            { idToken = "", accessToken = "", refreshToken = "", expiresIn = 0 }

        actions =
            [ TodoList.GotAuthResponse (Ok authResponse)
            , TodoList.GotSubscriptionCheck (Ok True)
            ]

        newModel =
            applyList actions (\a -> TodoList.update a >> Tuple.first) model
    in
    newModel


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
                            , syncStatus = TodoList.SyncOffline
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
                        newModel =
                            authenticatedModel

                        authenticated =
                            case newModel.authState of
                                TodoList.Authenticated _ ->
                                    True

                                _ ->
                                    False
                    in
                    Expect.equal authenticated True
            ]
        , describe "Sync"
            [ test "GotSubscriptionCheck starts syncing" <|
                \_ ->
                    Expect.equal TodoList.Retreiving authenticatedModel.syncStatus
            , test "If GotNodes is empty, it's time to send our data up" <|
                \_ ->
                    case emptyUpdateM of
                        Nothing ->
                            Expect.fail "emptyUpdate should exist"

                        Just emptyUpdate ->
                            let
                                model =
                                    authenticatedModel

                                newModel =
                                    Tuple.first <| TodoList.update (TodoList.GotNodes (Ok emptyUpdate)) model
                            in
                            Expect.equal { model | syncStatus = TodoList.Updating } newModel
            ]
        ]
