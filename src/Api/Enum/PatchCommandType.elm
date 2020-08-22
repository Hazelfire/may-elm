-- Do not manually edit this file, it was auto-generated by dillonkearns/elm-graphql
-- https://github.com/dillonkearns/elm-graphql


module Api.Enum.PatchCommandType exposing (..)

import Json.Decode as Decode exposing (Decoder)


type PatchCommandType
    = Delete
    | Update


list : List PatchCommandType
list =
    [ Delete, Update ]


decoder : Decoder PatchCommandType
decoder =
    Decode.string
        |> Decode.andThen
            (\string ->
                case string of
                    "DELETE" ->
                        Decode.succeed Delete

                    "UPDATE" ->
                        Decode.succeed Update

                    _ ->
                        Decode.fail ("Invalid PatchCommandType type, " ++ string ++ " try re-running the @dillonkearns/elm-graphql CLI ")
            )


{-| Convert from the union type representing the Enum to a string that the GraphQL server will recognize.
-}
toString : PatchCommandType -> String
toString enum =
    case enum of
        Delete ->
            "DELETE"

        Update ->
            "UPDATE"


{-| Convert from a String representation to an elm representation enum.
This is the inverse of the Enum `toString` function. So you can call `toString` and then convert back `fromString` safely.

    Swapi.Enum.Episode.NewHope
        |> Swapi.Enum.Episode.toString
        |> Swapi.Enum.Episode.fromString
        == Just NewHope

This can be useful for generating Strings to use for <select> menus to check which item was selected.

-}
fromString : String -> Maybe PatchCommandType
fromString enumString =
    case enumString of
        "DELETE" ->
            Just Delete

        "UPDATE" ->
            Just Update

        _ ->
            Nothing
