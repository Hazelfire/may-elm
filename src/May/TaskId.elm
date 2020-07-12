module May.TaskId exposing (TaskId, generate)

import Random


type TaskId
    = TaskId String


{-| Generates a random id for tasks and folders
-}
generateId : Random.Generator String
generateId =
    Random.map String.fromList (Random.list 100 (Random.map Char.fromCode (Random.int 0 127)))


generate : Random.Generator TaskId
generate =
    Random.map TaskId generateId
