module May.Statistics exposing
    ( Label(..)
    , LabeledTask
    , LabeledTasks
    , TaskGroup
    , doneToday
    , doneTodayAndLater
    , dueDateRecommendations
    , endOfDay
    , folderLabelWithId
    , groupTasks
    , labelTasks
    , startOfDay
    , taskLabelWithId
    , taskUrgency
    , todo
    , urgency
    , velocity
    )

import May.FileSystem as FileSystem exposing (FileSystem)
import May.Folder exposing (Folder)
import May.Id exposing (Id)
import May.Task as Task exposing (Task)
import Time


taskUrgency : Time.Posix -> Task -> Float
taskUrgency now task =
    case Task.due task of
        Just dueDate ->
            let
                miliDue =
                    Time.posixToMillis dueDate

                miliNow =
                    Time.posixToMillis now

                timeInDays =
                    max (toFloat (miliDue - miliNow) / 1000 / 60 / 60 / 24) 1
            in
            if miliDue > miliNow then
                Task.duration task / timeInDays

            else
                0.0

        Nothing ->
            0.0


{-| Calculates how many hours per day of work you need to do to get everything
done by their due dates.

Pretends that you have not done the tasks that have been done today, so that
you can track your progress

-}
urgency : Time.Zone -> Time.Posix -> List Task -> Float
urgency here now tasks =
    let
        incomplete =
            doneTodayAndLater here now tasks
    in
    case groupTasks here now incomplete of
        [] ->
            0

        group :: _ ->
            -- urgency in groups must be strictly decreasing. So this one is the actual urgency
            group.urgency


isJust : Maybe a -> Bool
isJust x =
    case x of
        Just _ ->
            True

        Nothing ->
            False


type alias TaskGroup =
    { urgency : Float
    , start : Time.Posix
    , tasks : List Task
    }


{-| Group tasks! This is a fascinating idea! May 3.0

The point of this is that your tasks can be grouped into several "groups" with
strictly declining urgency. From those groups the recommended due dates can
be extrapolated, where the last element in the group always has a recommended due
date being it's actual due date.

It really requires a diagram...

-}
groupTasks : Time.Zone -> Time.Posix -> List Task -> List TaskGroup
groupTasks here now tasks =
    let
        isNotDoneWithDueDate task =
            case ( isDoneToday here now task || (Task.doneOn task == Nothing && Task.due task /= Nothing), Task.duration task ) of
                ( True, duration ) ->
                    duration > 0

                _ ->
                    False

        ( incomplete, _ ) =
            List.partition isNotDoneWithDueDate tasks

        sortedTasks =
            List.sortBy (\x -> Maybe.withDefault 0 (Maybe.map Time.posixToMillis (Task.due x))) incomplete

        eoy =
            endOfYesterday here now
    in
    List.reverse <| groupTasks_ here eoy sortedTasks []


type alias LabeledTask =
    { task : Task
    , start : Time.Posix
    , end : Time.Posix
    , urgency : Float
    }


{-| The pair of dates are: (recommended start, recommended end). The reason I have
recommended start is that it's possible to calculate the percentage you should complete today
from this value.
-}
dueDateRecommendations : Time.Zone -> Time.Posix -> List Task -> List LabeledTask
dueDateRecommendations here now tasks =
    dueDateRecommendations_ now (groupTasks here now tasks)


dueDateRecommendations_ : Time.Posix -> List TaskGroup -> List LabeledTask
dueDateRecommendations_ now groups =
    case groups of
        [] ->
            []

        group :: restGroups ->
            case group.tasks of
                [] ->
                    -- Should never occur. A Task group must have at least one element
                    dueDateRecommendations_ now restGroups

                task :: _ ->
                    case Task.due task of
                        Nothing ->
                            -- Also should never occur, Task groups should only have tasks with due dates
                            dueDateRecommendations_ now restGroups

                        Just dueDate ->
                            let
                                fullDuration =
                                    List.sum <| List.map Task.duration group.tasks

                                fullWidth =
                                    Time.posixToMillis dueDate - Time.posixToMillis group.start
                            in
                            interpolateDue group.urgency group.start fullWidth fullDuration 0 (List.reverse group.tasks) ++ dueDateRecommendations_ dueDate restGroups


interpolateDue : Float -> Time.Posix -> Int -> Float -> Float -> List Task -> List LabeledTask
interpolateDue groupUrgency start width fullDuration durationSoFar tasks =
    case tasks of
        [] ->
            []

        task :: restTasks ->
            let
                currentDuration =
                    durationSoFar + Task.duration task

                proportionThroughLast =
                    durationSoFar / fullDuration

                proportionThrough =
                    currentDuration / fullDuration

                recommendedStart =
                    Time.millisToPosix (floor (proportionThroughLast * toFloat width + toFloat (Time.posixToMillis start)))

                recommendedDue =
                    Time.millisToPosix (floor (proportionThrough * toFloat width + toFloat (Time.posixToMillis start)))
            in
            { task = task
            , start = recommendedStart
            , end = recommendedDue
            , urgency = groupUrgency
            }
                :: interpolateDue groupUrgency start width fullDuration currentDuration restTasks


firstWith : (a -> Bool) -> List a -> ( List a, List a )
firstWith func list =
    case list of
        [] ->
            ( [], [] )

        x :: xs ->
            if func x then
                let
                    ( inlist, outlist ) =
                        firstWith func xs
                in
                ( x :: inlist, outlist )

            else
                ( [], x :: xs )


groupTasks_ : Time.Zone -> Time.Posix -> List Task -> List TaskGroup -> List TaskGroup
groupTasks_ here now tasks groups =
    case tasks of
        [] ->
            groups

        task :: rest ->
            let
                due =
                    case Task.due task of
                        Just a ->
                            a

                        Nothing ->
                            Time.millisToPosix 0

                ( samedue, diffdue ) =
                    firstWith (Task.due >> (==) (Task.due task)) rest

                ( doneToday_, doneLater_ ) =
                    List.partition (isDoneToday here now) (task :: samedue)

                newTaskGroup =
                    newGroup now (doneLater_ ++ doneToday_) due

                newStart =
                    case Task.due task of
                        Just d ->
                            if Time.posixToMillis d < Time.posixToMillis now then
                                now

                            else
                                d

                        Nothing ->
                            -- This should not be possible, it's assued that all tasks have a due date
                            Time.millisToPosix 0
            in
            case groups of
                [] ->
                    -- Fantastic! If there are no groups yet, this task can make our first group
                    groupTasks_ here newStart diffdue [ newTaskGroup ]

                groups_ ->
                    groupTasks_ here newStart diffdue (balanceTaskGroups (newTaskGroup :: groups_))


{-| This makes the task groups the smallest possible that satisfies the constraint
that the urgencies of the tasks must be strictly decreasing
-}
balanceTaskGroups : List TaskGroup -> List TaskGroup
balanceTaskGroups unbalanced =
    case unbalanced of
        first :: second :: rest ->
            if first.urgency < second.urgency then
                first :: second :: rest

            else
                balanceTaskGroups (mergeTaskGroups second first :: rest)

        a ->
            -- A list with 0 or 1 item is already balanced
            a


{-| Merges the groups so that they become one!
-}
mergeTaskGroups : TaskGroup -> TaskGroup -> TaskGroup
mergeTaskGroups first second =
    let
        fullWidth =
            taskGroupLengthMillis first + taskGroupLengthMillis second

        fullHours =
            List.sum <| List.map Task.duration (first.tasks ++ second.tasks)
    in
    { urgency = min fullHours (fullHours / (toFloat fullWidth / 1000 / 60 / 60 / 24)) -- urgency cannot be larger than the duration of the tasks
    , start = first.start
    , tasks = second.tasks ++ first.tasks -- Order here is important, I want the last tasks to come first
    }


taskGroupLengthMillis : TaskGroup -> Int
taskGroupLengthMillis { start, tasks } =
    case tasks of
        [] ->
            0

        -- Not sure what this means, but is really not possible
        task :: _ ->
            -- First item in this list should be the last item in this group. It's due date marks the end of this group
            case Task.due task of
                Just due ->
                    Time.posixToMillis due - Time.posixToMillis start

                _ ->
                    0


newGroup : Time.Posix -> List Task -> Time.Posix -> TaskGroup
newGroup start tasks due =
    let
        timeUntilDueInDaysCapped =
            max 1 <| toFloat (Time.posixToMillis due - Time.posixToMillis start) / 1000 / 60 / 60 / 24
    in
    { urgency = List.sum (List.map Task.duration tasks) / timeUntilDueInDaysCapped
    , start = start
    , tasks = tasks
    }


type alias LabeledTasks =
    { overdue : List LabeledTask
    , doToday : List ( LabeledTask, Float )
    , doSoon : List LabeledTask
    , doLater : List LabeledTask
    , noDue : List Task
    , done : List Task
    , doneToday : List LabeledTask
    }


doneTodayAndLater : Time.Zone -> Time.Posix -> List Task -> List Task
doneTodayAndLater here now tasks =
    List.filter (\task -> isDoneToday here now task || Task.doneOn task == Nothing) tasks


endOfDay : Time.Zone -> Time.Posix -> Time.Posix
endOfDay here now =
    Time.millisToPosix <| Time.posixToMillis (endOfYesterday here now) + 1000 * 60 * 60 * 24


labelTasks : Time.Zone -> Time.Posix -> List Task -> LabeledTasks
labelTasks here now tasks =
    let
        incomplete =
            doneTodayAndLater here now tasks

        done =
            List.filter (Task.doneOn >> isJust) tasks

        ( hasDue, noDue ) =
            List.partition
                (\task ->
                    case ( Task.duration task, Task.due task ) of
                        ( duration, Just _ ) ->
                            duration > 0

                        _ ->
                            False
                )
                incomplete

        noDueNotDone =
            List.filter (Task.doneOn >> (==) Nothing) noDue

        reccomendations =
            dueDateRecommendations here now hasDue

        ( doneToday_, notDone ) =
            List.partition (.task >> isDoneToday here now) reccomendations

        isOverdue task =
            case Task.due task of
                Just due ->
                    Time.posixToMillis due < Time.posixToMillis now

                _ ->
                    False

        ( overdue, upcoming ) =
            List.partition (.task >> isOverdue) notDone

        eod =
            endOfDay here now

        isDueToday { start } =
            Time.posixToMillis start <= Time.posixToMillis eod

        ( doToday, doAfterToday ) =
            List.partition isDueToday upcoming

        maxUrgency =
            Maybe.map .urgency <| List.head reccomendations

        ( doSoon, doLater ) =
            List.partition (.urgency >> Just >> (==) maxUrgency) doAfterToday

        rangeToPercentage labeledTask =
            let
                percentageDone =
                    if Time.posixToMillis labeledTask.end <= Time.posixToMillis eod then
                        1

                    else
                        toFloat (Time.posixToMillis eod - Time.posixToMillis labeledTask.start) / toFloat (Time.posixToMillis labeledTask.end - Time.posixToMillis labeledTask.start)
            in
            ( labeledTask, percentageDone )
    in
    { done = done
    , noDue = noDueNotDone
    , doSoon = doSoon
    , doLater = doLater
    , doToday = List.map rangeToPercentage doToday
    , overdue = overdue
    , doneToday = doneToday_
    }


startOfDay : Time.Zone -> Time.Posix -> Time.Posix
startOfDay zone time =
    let
        hoursSinceStart =
            Time.toHour zone time

        minutesSinceStart =
            hoursSinceStart * 60 + Time.toMinute zone time

        secondsSinceStart =
            minutesSinceStart * 60 + Time.toSecond zone time

        millisSinceStart =
            secondsSinceStart * 1000 + Time.toMillis zone time
    in
    Time.millisToPosix (Time.posixToMillis time - millisSinceStart)


endOfYesterday : Time.Zone -> Time.Posix -> Time.Posix
endOfYesterday zone time =
    Time.millisToPosix <| Time.posixToMillis (startOfDay zone time) - 1000


isDoneToday : Time.Zone -> Time.Posix -> Task -> Bool
isDoneToday zone time t =
    case Task.doneOn t of
        Just doneOn ->
            Time.posixToMillis doneOn >= Time.posixToMillis (startOfDay zone time)

        Nothing ->
            False


doneToday : Time.Zone -> Time.Posix -> List Task -> List Task
doneToday zone time tasks =
    List.filter (isDoneToday zone time) tasks


type Label
    = Overdue
    | DoToday
    | DoSoon
    | DoLater
    | NoDue
    | Done
    | DoneToday


taskLabelWithId : LabeledTasks -> Id Task -> Label
taskLabelWithId taskLabels taskId =
    if List.any (.task >> Task.id >> (==) taskId) taskLabels.overdue then
        Overdue

    else if List.any (Tuple.first >> .task >> Task.id >> (==) taskId) taskLabels.doToday then
        DoToday

    else if List.any (.task >> Task.id >> (==) taskId) taskLabels.doSoon then
        DoSoon

    else if List.any (.task >> Task.id >> (==) taskId) taskLabels.doLater then
        DoLater

    else if List.any (Task.id >> (==) taskId) taskLabels.noDue then
        NoDue

    else
        Done


folderLabelWithId : LabeledTasks -> Id Folder -> FileSystem -> Label
folderLabelWithId taskLabels folderId fs =
    let
        taskHasParent =
            Task.id
                >> (\x -> FileSystem.taskParent x fs)
                >> (\x ->
                        case x of
                            Just y ->
                                FileSystem.folderHasAncestor y folderId fs

                            Nothing ->
                                False
                   )
    in
    if List.any (.task >> taskHasParent) taskLabels.overdue then
        Overdue

    else if List.any (Tuple.first >> .task >> taskHasParent) taskLabels.doToday then
        DoToday

    else if List.any (.task >> taskHasParent) taskLabels.doSoon then
        DoSoon

    else if List.any (.task >> taskHasParent) taskLabels.doLater then
        DoLater

    else if List.any taskHasParent taskLabels.noDue then
        NoDue

    else
        Done



{- Calculates the urgency of a sublist. The second argument and second tuple
   is the residual. Assumes all tasks are in order of due date
-}


taskVelocity : Time.Posix -> Task -> Float
taskVelocity now task =
    case Task.due task of
        Just dueDate ->
            let
                miliDue =
                    Time.posixToMillis dueDate

                miliNow =
                    Time.posixToMillis now

                timeInDays =
                    toFloat (miliDue - miliNow) / 60 / 60 / 1000 / 24
            in
            if miliDue > miliNow then
                Task.duration task / timeInDays / timeInDays

            else
                0.0

        Nothing ->
            0.0


velocity : Time.Posix -> List Task -> Float
velocity now tasks =
    List.sum (List.map (taskVelocity now) tasks)


todo : Time.Posix -> List Task -> List Task
todo now tasks =
    List.sortBy (taskUrgency now >> (*) -1) tasks
