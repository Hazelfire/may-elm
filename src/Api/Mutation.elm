-- Do not manually edit this file, it was auto-generated by dillonkearns/elm-graphql
-- https://github.com/dillonkearns/elm-graphql


module Api.Mutation exposing (..)

import Api.InputObject
import Api.Interface
import Api.Object
import Api.Scalar
import Api.Union
import CustomScalarCodecs
import Graphql.Internal.Builder.Argument as Argument exposing (Argument)
import Graphql.Internal.Builder.Object as Object
import Graphql.Internal.Encode as Encode exposing (Value)
import Graphql.Operation exposing (RootMutation, RootQuery, RootSubscription)
import Graphql.OptionalArgument exposing (OptionalArgument(..))
import Graphql.SelectionSet exposing (SelectionSet)
import Json.Decode as Decode exposing (Decoder)


type alias PatchNodesRequiredArguments =
    { args : List Api.InputObject.PatchCommand }


patchNodes :
    PatchNodesRequiredArguments
    -> SelectionSet decodesTo Api.Object.OkResult
    -> SelectionSet decodesTo RootMutation
patchNodes requiredArgs object_ =
    Object.selectionForCompositeField "patchNodes" [ Argument.required "args" requiredArgs.args (Api.InputObject.encodePatchCommand |> Encode.list) ] object_ identity


deleteUser :
    SelectionSet decodesTo Api.Object.OkResult
    -> SelectionSet decodesTo RootMutation
deleteUser object_ =
    Object.selectionForCompositeField "deleteUser" [] object_ identity


requestSubscriptionSession : SelectionSet String RootMutation
requestSubscriptionSession =
    Object.selectionForField "String" "requestSubscriptionSession" [] Decode.string
