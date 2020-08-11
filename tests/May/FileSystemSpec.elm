module May.FileSystemSpec exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Json.Decode as D
import Json.Encode as E
import May.FileSystem as FileSystem
import May.Folder as Folder exposing (Folder)
import May.Id as Id exposing (Id)
import May.SyncList as SyncList
import May.Task as Task exposing (Task)
import Test exposing (..)


emptyList : E.Value
emptyList =
    E.list (\x -> x) []


rootId : Id Folder
rootId =
    Id.testId "root"


root : Folder
root =
    Folder.new rootId "root"


initFS : FileSystem.FileSystem
initFS =
    FileSystem.new root


task : String -> Task
task name =
    let
        taskId =
            Id.testId name

        newTask =
            Task.new taskId name
    in
    newTask


suite : Test
suite =
    describe "FileSystem"
        [ describe "Adding Nodes"
            [ test "adding tasks doesn't delete root" <|
                \_ ->
                    let
                        newFS =
                            FileSystem.addTask rootId (task "newTask") initFS

                        allFolders =
                            FileSystem.allFolders newFS
                    in
                    Expect.equal allFolders [ root ]
            ]
        , describe "Deleting Nodes" <|
            [ test "deletes tasks" <|
                \_ ->
                    let
                        taskId =
                            Id.testId "child"

                        newTask =
                            Task.new taskId "New Task"

                        newFS =
                            FileSystem.addTask rootId newTask initFS

                        newFS2 =
                            FileSystem.deleteTask taskId newFS

                        retrievedTasks =
                            FileSystem.tasksInFolder rootId newFS2
                    in
                    Expect.equal retrievedTasks []
            , test "deletes folders" <|
                \_ ->
                    let
                        folderId =
                            Id.testId "child"

                        newFolder =
                            Folder.new folderId "New Folder"

                        newFS =
                            FileSystem.addFolder rootId newFolder initFS

                        newFS2 =
                            FileSystem.deleteFolder folderId newFS

                        retrievedFolders =
                            FileSystem.foldersInFolder rootId newFS2
                    in
                    Expect.equal retrievedFolders []
            ]
        , describe "Serialisation"
            [ test "decoding a filesystem with an empty synclist doesn't need syncing" <|
                \_ ->
                    let
                        fileSystemValue =
                            E.object [ ( "tasks", emptyList ), ( "folders", E.list Folder.encode [ root ] ), ( "edges", emptyList ), ( "root", E.string "root" ), ( "synclist", SyncList.encode SyncList.empty ) ]
                    in
                    case D.decodeValue FileSystem.decode fileSystemValue of
                        Ok fs ->
                            Expect.equal False (FileSystem.needsSync fs)

                        Err _ ->
                            Expect.fail "Expected to be able to decode the filesystem"
            ]
        ]
