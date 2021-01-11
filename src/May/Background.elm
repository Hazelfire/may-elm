module May.Background exposing (view)

import Html exposing (Html)
import May.Statistics as Statistics
import Time
import TypedSvg as Svg
import TypedSvg.Attributes as SvgAttr
import TypedSvg.Attributes.InPx as SvgPx
import TypedSvg.Core as Svg
import TypedSvg.Events as Svg
import TypedSvg.Types as Svg


reductionFactor : Float
reductionFactor =
    0.7


treeHeight : Float
treeHeight =
    0.15


treeWidth : Float
treeWidth =
    0.01


treeCurve : Float
treeCurve =
    3


rotatePoint : Float -> ( Float, Float ) -> ( Float, Float )
rotatePoint angle ( x, y ) =
    ( cos angle * x - sin angle * y, sin angle * x + cos angle * y )


treeRotate : Float
treeRotate =
    pi / 5


leafRotation : Int -> Int -> Float
leafRotation size index =
    if size == 0 then
        0

    else
        let
            rotateLeft =
                modBy 2 (floor (logBase 2 (toFloat size))) == 0

            rightAngle =
                if rotateLeft then
                    0

                else
                    treeRotate

            leftAngle =
                if rotateLeft then
                    -treeRotate

                else
                    0
        in
        if modBy 2 index == 0 then
            rightAngle + leafRotation (size // 2) (index // 2)

        else
            leftAngle + leafRotation ((size - 1) // 2) (index // 2)


leafPosition : Int -> Int -> ( Float, Float )
leafPosition size index =
    if size == 0 then
        ( 0, -treeHeight )

    else
        let
            rotateLeft =
                modBy 2 (floor (logBase 2 (toFloat size))) == 0

            rightAngle =
                if rotateLeft then
                    0

                else
                    treeRotate

            leftAngle =
                if rotateLeft then
                    -treeRotate

                else
                    0

            ( x, y ) =
                if modBy 2 index == 0 then
                    rotatePoint rightAngle <| leafPosition (size // 2) (index // 2)

                else
                    rotatePoint leftAngle <| leafPosition ((size - 1) // 2) (index // 2)
        in
        ( reductionFactor * x, reductionFactor * y - treeHeight )


last : List a -> Maybe a
last list =
    case list of
        [] ->
            Nothing

        item :: [] ->
            Just item

        _ :: rest ->
            last rest


listInit : List a -> List a
listInit list =
    case list of
        [] ->
            []

        _ :: [] ->
            []

        x :: rest ->
            x :: listInit rest


type CurveSegment
    = Smooth ( Float, Float ) ( Float, Float )


type CurvePoint
    = SmoothPoint ( Float, Float )
    | SharpPoint ( Float, Float )


transformPoint : (( Float, Float ) -> ( Float, Float )) -> CurvePoint -> CurvePoint
transformPoint func segment =
    case segment of
        SmoothPoint p1 ->
            SmoothPoint (func p1)

        SharpPoint p1 ->
            SharpPoint (func p1)


getCurvePoint : CurvePoint -> ( Float, Float )
getCurvePoint segment =
    case segment of
        SmoothPoint p1 ->
            p1

        SharpPoint p1 ->
            p1


segmentToString : CurveSegment -> String
segmentToString segment =
    case segment of
        Smooth ( cx1, cy1 ) ( px1, py1 ) ->
            String.join " "
                [ "S"
                , String.fromFloat cx1
                , String.fromFloat cy1
                , ","
                , String.fromFloat px1
                , String.fromFloat py1
                ]


midpointPoints : CurvePoint -> CurvePoint -> CurvePoint
midpointPoints s1 s2 =
    case s1 of
        SmoothPoint p1 ->
            transformPoint (\p2 -> midpoint p1 p2) s2

        SharpPoint p1 ->
            transformPoint (\p2 -> midpoint p1 p2) s2


midpoint : ( Float, Float ) -> ( Float, Float ) -> ( Float, Float )
midpoint ( x1, y1 ) ( x2, y2 ) =
    ( (x1 + x2) / 2, (y1 + y2) / 2 )


branchPositions : Float -> Int -> List CurvePoint
branchPositions width index =
    if index == 0 then
        [ SmoothPoint ( -width, 0 ), SharpPoint ( 0, -treeHeight ), SmoothPoint ( width, 0 ) ]

    else
        let
            rotateLeft =
                modBy 2 (floor (logBase 2 (toFloat index))) == 0

            rightAngle =
                if rotateLeft then
                    0

                else
                    treeRotate

            leftAngle =
                if rotateLeft then
                    -treeRotate

                else
                    0

            lefts =
                List.map (transformPoint <| (\( x, y ) -> ( reductionFactor * x, reductionFactor * y - treeHeight )) << rotatePoint rightAngle) (branchPositions width (index // 2))

            rights =
                List.map (transformPoint <| (\( x, y ) -> ( reductionFactor * x, reductionFactor * y - treeHeight )) << rotatePoint leftAngle) (branchPositions width ((index - 1) // 2))
        in
        case ( last rights, lefts ) of
            ( Just rightPoint, leftPoint :: restLefts ) ->
                let
                    midCurvePoint =
                        midpointPoints rightPoint leftPoint
                in
                (SmoothPoint ( -width, 0 ) :: (listInit rights ++ (midCurvePoint :: restLefts))) ++ [ SmoothPoint ( width, 0 ) ]

            _ ->
                -- Not Possible
                []


type alias LeafTransform =
    { x : Float
    , y : Float
    , angle : Float
    }


leavePositions : Int -> Int -> List LeafTransform
leavePositions leafCount size =
    if leafCount == 0 then
        []

    else
        let
            ( x, y ) =
                leafPosition (size - 1) (leafCount - 1)

            angle =
                leafRotation (size - 1) (leafCount - 1)
        in
        { x = x, y = y, angle = angle * 180 / pi } :: leavePositions (leafCount - 1) size


view : Time.Zone -> Time.Posix -> Statistics.LabeledTasks -> Html msg
view here now labeledTasks =
    let
        planetHeight =
            0.2

        planetSize =
            3

        redLeaves =
            List.length labeledTasks.overdue

        orangeLeaves =
            List.length labeledTasks.doToday

        yellowLeaves =
            List.length labeledTasks.doSoon

        greenLeaves =
            List.length labeledTasks.doLater

        extraBranches =
            List.length labeledTasks.noDue

        totalLeaves =
            redLeaves + orangeLeaves + yellowLeaves + greenLeaves

        totalBranches =
            totalLeaves + extraBranches

        leafClasses =
            List.concat
                [ List.repeat redLeaves "overdueleaf"
                , List.repeat orangeLeaves "dotodayleaf"
                , List.repeat yellowLeaves "dosoonleaf"
                , List.repeat greenLeaves "dolaterleaf"
                ]

        planetBase =
            1 - planetHeight
    in
    Svg.svg [ SvgAttr.viewBox 0 0 1 1, SvgAttr.class [ "background" ] ]
        [ Svg.circle
            [ SvgPx.cx 0.5
            , SvgPx.cy (1 + planetSize - planetHeight)
            , SvgPx.r planetSize
            , SvgAttr.class [ "earth" ]
            ]
            []
        , Svg.g
            [ SvgAttr.transform [ Svg.Translate 0.5 planetBase ] ]
            (if totalBranches > 0 then
                let
                    branchPos =
                        branchPositions (logBase 2 (toFloat totalBranches + 1) * treeWidth) (totalBranches - 1)
                in
                constructTreePath branchPos
                    :: (if totalLeaves > 0 then
                            [ Svg.g [] (List.map2 (\leafClass { x, y, angle } -> Svg.g [ SvgAttr.transform [ Svg.Translate x y, Svg.Rotate angle 0 0 ] ] [ viewLeaf leafClass ]) leafClasses (leavePositions totalLeaves totalBranches)) ]

                        else
                            []
                       )

             else
                []
            )
        ]


addPoints : ( Float, Float ) -> ( Float, Float ) -> ( Float, Float )
addPoints ( x1, y1 ) ( x2, y2 ) =
    ( x1 + x2, y1 + y2 )


multiplyPoints : Float -> ( Float, Float ) -> ( Float, Float )
multiplyPoints s ( x, y ) =
    ( s * x, s * y )


subtractPoints : ( Float, Float ) -> ( Float, Float ) -> ( Float, Float )
subtractPoints p1 p2 =
    addPoints p1 (multiplyPoints -1 p2)


setSize : Float -> ( Float, Float ) -> ( Float, Float )
setSize size ( x, y ) =
    multiplyPoints (size * sqrt (x * x + y * y)) ( x, y )


curvePointsToCurveSegments : List CurvePoint -> List CurveSegment
curvePointsToCurveSegments points =
    case points of
        p1 :: (SmoothPoint p2) :: p3 :: rest ->
            let
                firstControl =
                    midpoint (getCurvePoint p1) (addPoints p2 (subtractPoints p2 (getCurvePoint p3)))

                vector =
                    setSize treeCurve (subtractPoints firstControl p2)
            in
            Smooth (addPoints vector p2) p2 :: curvePointsToCurveSegments (SmoothPoint p2 :: p3 :: rest)

        p1 :: (SharpPoint p2) :: p3 :: rest ->
            Smooth p2 p2 :: curvePointsToCurveSegments (SharpPoint p2 :: p3 :: rest)

        [] ->
            []

        _ :: [] ->
            []

        _ :: p2 :: [] ->
            [ Smooth (getCurvePoint p2) (getCurvePoint p2) ]


constructTreePath : List CurvePoint -> Svg.Svg msg
constructTreePath points =
    case points of
        firstPoint :: _ ->
            let
                ( x, y ) =
                    getCurvePoint firstPoint
            in
            Svg.path
                [ SvgAttr.class [ "tree" ]
                , SvgAttr.d <|
                    String.join " "
                        ([ "M"
                         , String.fromFloat x
                         , String.fromFloat y
                         ]
                            ++ List.map segmentToString (curvePointsToCurveSegments points)
                        )
                ]
                []

        _ ->
            -- What the hell is a path with one point?! No!!! (Should never happen)
            Svg.g [] []


viewLeaf : String -> Svg.Svg msg
viewLeaf leafClass =
    let
        upperWidth =
            String.fromFloat 0.5

        lowerWidth =
            String.fromFloat 0.1
    in
    Svg.g [ SvgAttr.transform [ Svg.Rotate 180 0 0 ] ]
        [ Svg.path
            [ SvgAttr.class [ leafClass ]
            , SvgAttr.transform [ Svg.Scale 0.07 0.07 ]
            , SvgAttr.d <| "M 0 1 C -" ++ upperWidth ++ " 0 ,-" ++ lowerWidth ++ " 0 ,0 0 C " ++ lowerWidth ++ " 0, " ++ upperWidth ++ " 0, 0 1"
            ]
            []
        ]
