-- Do not manually edit this file, it was auto-generated by dillonkearns/elm-graphql
-- https://github.com/dillonkearns/elm-graphql


module Api.Object.Task exposing (..)

import Api.InputObject
import Api.Interface
import Api.Object
import Api.Scalar
import Api.ScalarCodecs
import Api.Union
import Graphql.Internal.Builder.Argument as Argument exposing (Argument)
import Graphql.Internal.Builder.Object as Object
import Graphql.Internal.Encode as Encode exposing (Value)
import Graphql.Operation exposing (RootMutation, RootQuery, RootSubscription)
import Graphql.OptionalArgument exposing (OptionalArgument(..))
import Graphql.SelectionSet exposing (SelectionSet)
import Json.Decode as Decode


id : SelectionSet Api.ScalarCodecs.Id Api.Object.Task
id =
    Object.selectionForField "ScalarCodecs.Id" "id" [] (Api.ScalarCodecs.codecs |> Api.Scalar.unwrapCodecs |> .codecId |> .decoder)


name : SelectionSet String Api.Object.Task
name =
    Object.selectionForField "String" "name" [] Decode.string


due : SelectionSet (Maybe Int) Api.Object.Task
due =
    Object.selectionForField "(Maybe Int)" "due" [] (Decode.int |> Decode.nullable)


pid : SelectionSet Api.ScalarCodecs.Id Api.Object.Task
pid =
    Object.selectionForField "ScalarCodecs.Id" "pid" [] (Api.ScalarCodecs.codecs |> Api.Scalar.unwrapCodecs |> .codecId |> .decoder)


duration : SelectionSet Int Api.Object.Task
duration =
    Object.selectionForField "Int" "duration" [] Decode.int
