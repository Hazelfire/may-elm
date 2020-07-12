module May.Task exposing
    ( Task
    , generate
    , id
    , name
    , parent
    )

import May.FolderId exposing (FolderId)
import May.TaskId as TaskId exposing (TaskId)
import Random


type Task
    = Task
        { id : TaskId
        , name : String
        , duration : Float
        , dependencies : List TaskId
        , labels : List String
        , parent : FolderId
        }


generate : FolderId -> Random.Generator Task
generate parentId =
    Random.map (\x -> Task { id = x, name = "New Task", duration = 0.0, dependencies = [], labels = [], parent = parentId }) TaskId.generate


parent : Task -> FolderId
parent (Task task) =
    task.parent


id : Task -> TaskId
id (Task task) =
    task.id


name : Task -> String
name (Task task) =
    task.name
