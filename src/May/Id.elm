module May.Id exposing (Id, decode, encode, generate, magic, rootId, testId)

import Api.Scalar
import Api.ScalarCodecs
import Graphql.SelectionSet as Graphql
import Json.Decode as D
import Json.Encode as E
import Random
import Uuid.Barebones


type Id a
    = Id String


{-| Generates a random id for tasks and folders
-}
generateId : Random.Generator String
generateId =
    Uuid.Barebones.uuidStringGenerator


{-| I am only using this for the code generation in GraphQL. Please don't use it often
-}
magic : Id a -> Id b
magic (Id a) =
    Id a


generate : Random.Generator (Id a)
generate =
    Random.map Id generateId


encode : Id a -> E.Value
encode (Id str) =
    E.string str


decode : D.Decoder (Id a)
decode =
    D.map Id D.string


{-| Should never be used in production, only exists to create ids purely in tests
-}
testId : String -> Id a
testId s =
    Id s


rootId : Id a
rootId =
    Id "root"
