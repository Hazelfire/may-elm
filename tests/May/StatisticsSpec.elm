module May.StatisticsSpec exposing (suite)

import Expect
import Json.Encode as E
import May.FileSystem as FileSystem
import May.Id as Id exposing (Id)
import May.Statistics as Statistics
import May.Task as Task
import Test exposing (..)
import Time
import TodoList
import Tuple


daysToMilis : Float -> Int
daysToMilis days =
    floor (days * 24 * 60 * 60 * 1000)


expectFloatEqual : Float -> Float -> Expect.Expectation
expectFloatEqual float1 float2 =
    Expect.within (Expect.Absolute 0.0001) float1 float2


suite : Test
suite =
    describe "Statistics"
        [ describe "Urgency"
            [ test "urgency is not larger than duration" <|
                \_ ->
                    let
                        task =
                            Task.new (Id.testId "task") "New Task"
                                |> Task.setDue (Just (Time.millisToPosix 10))
                                |> Task.setDuration 2

                        urgency =
                            Statistics.urgency (Time.millisToPosix 0) [ task ]
                    in
                    expectFloatEqual urgency 2.0
            , test "urgency calculates hours per day" <|
                \_ ->
                    let
                        task =
                            Task.new (Id.testId "task") "New Task"
                                |> Task.setDue (Just (Time.millisToPosix (daysToMilis 4)))
                                |> Task.setDuration 2

                        urgency =
                            Statistics.urgency (Time.millisToPosix 0) [ task ]
                    in
                    expectFloatEqual urgency 0.5
            , test "urgency hides behind due dates" <|
                \_ ->
                    let
                        task =
                            Task.new (Id.testId "task") "New Task"
                                |> Task.setDue (Just (Time.millisToPosix (daysToMilis 1)))
                                |> Task.setDuration 1

                        task2 =
                            Task.new (Id.testId "task2") "New Task2"
                                |> Task.setDue (Just (Time.millisToPosix (daysToMilis 2)))
                                |> Task.setDuration 1

                        urgency =
                            Statistics.urgency (Time.millisToPosix 0) [ task, task2 ]
                    in
                    expectFloatEqual urgency 1.0
            , test "urgency can overflows" <|
                \_ ->
                    let
                        task =
                            Task.new (Id.testId "task") "New Task"
                                |> Task.setDue (Just (Time.millisToPosix (daysToMilis 1)))
                                |> Task.setDuration 1

                        task2 =
                            Task.new (Id.testId "task2") "New Task2"
                                |> Task.setDue (Just (Time.millisToPosix (daysToMilis 2)))
                                |> Task.setDuration 2

                        urgency =
                            Statistics.urgency (Time.millisToPosix 0) [ task, task2 ]
                    in
                    expectFloatEqual urgency 1.5
            ]
        , describe "Task Labels"
            [ test "sole task is in doSoon" <|
                \_ ->
                    let
                        task =
                            Task.new (Id.testId "task") "New Task"
                                |> Task.setDue (Just (Time.millisToPosix (daysToMilis 4)))
                                |> Task.setDuration 2

                        labels =
                            Statistics.labelTasks (Time.millisToPosix 0) [ task ]
                    in
                    Expect.equal [ ( task, 0.5 ) ] labels.doSoon
            , test "task behind is doLater" <|
                \_ ->
                    let
                        task =
                            Task.new (Id.testId "task") "New Task"
                                |> Task.setDue (Just (Time.millisToPosix (daysToMilis 1.1)))
                                |> Task.setDuration 2

                        task2 =
                            Task.new (Id.testId "task2") "New Task2"
                                |> Task.setDue (Just (Time.millisToPosix (daysToMilis 2)))
                                |> Task.setDuration 1

                        labels =
                            Statistics.labelTasks (Time.millisToPosix 0) [ task, task2 ]
                    in
                    Expect.equal ( 1, 1 ) ( List.length labels.doSoon, List.length labels.doLater )
            , test "labels overflow" <|
                \_ ->
                    let
                        task =
                            Task.new (Id.testId "task") "New Task"
                                |> Task.setDue (Just (Time.millisToPosix (daysToMilis 2)))
                                |> Task.setDuration 2

                        task2 =
                            Task.new (Id.testId "task2") "New Task2"
                                |> Task.setDue (Just (Time.millisToPosix (daysToMilis 4)))
                                |> Task.setDuration 4

                        labels =
                            Statistics.labelTasks (Time.millisToPosix 0) [ task, task2 ]
                    in
                    Expect.equal [ ( task, 1.0 ), ( task2, 0.5 ) ] labels.doSoon
            ]
        ]
