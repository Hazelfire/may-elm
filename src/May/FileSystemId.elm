module May.Id exposing (Id, generate)

import Random


type Id a
    = Id String


{-| Generates a random id for tasks and folders
-}
generateId : Random.Generator String
generateId =
    Random.map String.fromList (Random.list 100 (Random.map Char.fromCode (Random.int 0 127)))


generate : Random.Generator (Id a)
generate =
    Random.map Id generateId
