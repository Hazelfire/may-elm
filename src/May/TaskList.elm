module May.TaskList exposing
    ( TaskList
    , addTask
    , delete
    , new
    , taskWithId
    , tasksInFolder
    , tasksInFolderRecursive
    )

import May.Folder as Folder
import May.FolderId exposing (FolderId)
import May.FolderList as FolderList exposing (FolderList)
import May.Task as Task exposing (Task)
import May.TaskId exposing (TaskId)


type TaskList
    = TaskList (List Task)


new : TaskList
new =
    TaskList []


addTask : TaskList -> Task -> TaskList
addTask (TaskList tasks) task =
    TaskList <| task :: tasks


taskWithId : TaskList -> TaskId -> Maybe Task
taskWithId (TaskList tasks) id =
    case List.filter (Task.id >> (==) id) tasks of
        x :: _ ->
            Just x

        _ ->
            Nothing


{-| Gets all the tasks in a directory
-}
tasksInFolder : TaskList -> FolderId -> List Task
tasksInFolder (TaskList tasks) parentId =
    List.filter (Task.parent >> (==) parentId) tasks


{-| Gets all the tasks in a directory recursively
-}
tasksInFolderRecursive : FolderList -> TaskList -> FolderId -> List Task.Task
tasksInFolderRecursive folders tasks parentId =
    let
        subTasks =
            tasksInFolder tasks parentId

        subFolders =
            FolderList.foldersInFolder folders parentId

        subFoldersId =
            List.map Folder.id subFolders
    in
    subTasks ++ List.concat (List.map (tasksInFolderRecursive folders tasks) subFoldersId)


delete : TaskList -> TaskId -> TaskList
delete (TaskList tasks) taskId =
    TaskList <| List.filter (Task.id >> (/=) taskId) tasks
