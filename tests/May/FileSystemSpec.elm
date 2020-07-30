module May.FileSystemSpec exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import May.FileSystem as FileSystem
import May.Folder as Folder exposing (Folder)
import May.Id as Id exposing (Id)
import May.Task as Task
import Test exposing (..)


rootId : Id Folder
rootId =
    Id.testId "root"


root : Folder
root =
    Folder.new rootId "root"


initFS : FileSystem.FileSystem
initFS =
    FileSystem.new root


suite : Test
suite =
    describe "FileSystem"
        [ test "adding tasks doesn't delete root" <|
            \_ ->
                let
                    taskId =
                        Id.testId "child"

                    newTask =
                        Task.new taskId "New Task"

                    newFS =
                        FileSystem.addTask rootId newTask initFS

                    allFolders =
                        FileSystem.allFolders newFS
                in
                Expect.equal allFolders [ root ]
        , test "deletes tasks" <|
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
