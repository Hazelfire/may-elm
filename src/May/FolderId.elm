module May.FolderId exposing (FolderId, generate)

import Random


type FolderId
    = FolderId String


{-| Generates a random id for tasks and folders
-}
generateId : Random.Generator String
generateId =
    Random.map String.fromList (Random.list 100 (Random.map Char.fromCode (Random.int 0 127)))


generate : Random.Generator FolderId
generate =
    Random.map FolderId generateId
