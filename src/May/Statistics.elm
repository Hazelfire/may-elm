module May.Statistics exposing
    ( Label(..)
    , LabeledTasks
    , doneToday
    , dueDateRecommendations
    , folderLabelWithId
    , groupTasks
    , labelTasks
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
        ( donetoday_, notDoneToday ) =
            List.partition (isDoneToday here now) tasks

        pretendingNotDone =
            List.map (Task.setDoneOn Nothing) donetoday_ ++ notDoneToday

        taskLabels =
            labelTasks here now pretendingNotDone

        doTodayTime =
            List.sum (List.map Task.duration (taskLabels.overdue ++ taskLabels.doToday))

        doSoonTime =
            List.sum (List.map Tuple.second taskLabels.doSoon)
    in
    doSoonTime + doTodayTime


type alias LabeledTasks =
    { overdue : List Task
    , doToday : List Task
    , doSoon : List ( Task, Float )
    , doLater : List Task
    , done : List Task
    }


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
            case ( Task.due task, Task.doneOn task, Task.duration task ) of
                ( Just _, Nothing, duration ) ->
                    duration > 0

                _ ->
                    False

        ( _, incomplete ) =
            List.partition isNotDoneWithDueDate tasks

        sortedTasks =
            List.sortBy (\x -> Maybe.withDefault 0 (Maybe.map Time.posixToMillis (Task.due x))) incomplete

        sod =
            startOfDay here now
    in
    List.reverse <| groupTasks_ sod sortedTasks []


dueDateRecommendations : Time.Zone -> Time.Posix -> List Task -> List ( Time.Posix, Task )
dueDateRecommendations here now tasks =
    dueDateRecommendations_ now (groupTasks here now tasks)


dueDateRecommendations_ : Time.Posix -> List TaskGroup -> List ( Time.Posix, Task )
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
                            interpolateDue group.start fullWidth fullDuration 0 (List.reverse group.tasks) ++ dueDateRecommendations_ dueDate restGroups


interpolateDue : Time.Posix -> Int -> Float -> Float -> List Task -> List ( Time.Posix, Task )
interpolateDue start width fullDuration durationSoFar tasks =
    case tasks of
        [] ->
            []

        task :: restTasks ->
            let
                currentDuration =
                    durationSoFar + Task.duration task

                proportionThrough =
                    currentDuration / fullDuration
            in
            ( Time.millisToPosix (floor (proportionThrough * toFloat width + toFloat (Time.posixToMillis start))), task ) :: interpolateDue start width fullDuration currentDuration restTasks


groupTasks_ : Time.Posix -> List Task -> List TaskGroup -> List TaskGroup
groupTasks_ now tasks groups =
    case tasks of
        [] ->
            groups

        task :: rest ->
            let
                newTaskGroup =
                    newGroup now task

                newStart =
                    case Task.due task of
                        Just d ->
                            d

                        Nothing ->
                            Time.millisToPosix 0

                -- This should not be possible, it's assued that all tasks have a due date
            in
            case groups of
                [] ->
                    -- Fantastic! If there are no groups yet, this task can make our first group
                    groupTasks_ newStart rest [ newTaskGroup ]

                lastGroup :: restGroups ->
                    -- Now, the golden question is, is the urgency to this group smaller than the last?
                    if lastGroup.urgency > newTaskGroup.urgency then
                        -- If so, then we can also just add this group to the list
                        groupTasks_ newStart rest (newTaskGroup :: lastGroup :: restGroups)

                    else
                        -- Otherwise, we need to merge the groups
                        groupTasks_ newStart rest (balanceTaskGroups (newTaskGroup :: lastGroup :: restGroups))


{-| This makes the task groups the smallest possible that satisfies the constraint
that the urgencies of the tasks must be strictly decreasing
-}
balanceTaskGroups : List TaskGroup -> List TaskGroup
balanceTaskGroups unbalanced =
    case unbalanced of
        first :: second :: rest ->
            if first.urgency < second.urgency then
                balanceTaskGroups (mergeTaskGroups first second :: rest)

            else
                first :: second :: rest

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
    { urgency = max fullHours (fullHours / (toFloat fullWidth / 1000 / 60 / 60 / 24)) -- urgency cannot be larger than the duration of the tasks
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


newGroup : Time.Posix -> Task -> TaskGroup
newGroup start task =
    let
        due =
            case Task.due task of
                Just d ->
                    d

                Nothing ->
                    Time.millisToPosix 0

        timeUntilDueInDaysCapped =
            max 1 <| toFloat (Time.posixToMillis due - Time.posixToMillis start) / 1000 / 60 / 60 / 24
    in
    { urgency = Task.duration task / timeUntilDueInDaysCapped
    , start = start
    , tasks = [ task ]
    }


labelTasks : Time.Zone -> Time.Posix -> List Task -> LabeledTasks
labelTasks here now tasks =
    let
        ( done, incomplete ) =
            List.partition (Task.doneOn >> isJust) tasks

        sortedTasks =
            List.sortBy (\x -> Maybe.withDefault 0 (Maybe.map Time.posixToMillis (Task.due x))) incomplete

        sod =
            startOfDay here now

        labeledTasks =
            labelTasks_ sod sod 0 0 sortedTasks
    in
    { labeledTasks | done = done }


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


isDoneToday : Time.Zone -> Time.Posix -> Task -> Bool
isDoneToday zone time t =
    case Task.doneOn t of
        Just doneOn ->
            Time.posixToMillis doneOn > Time.posixToMillis (startOfDay zone time)

        Nothing ->
            False


doneToday : Time.Zone -> Time.Posix -> List Task -> List Task
doneToday zone time tasks =
    List.filter (isDoneToday zone time) tasks


labelTasks_ : Time.Posix -> Time.Posix -> Float -> Float -> List Task -> LabeledTasks
labelTasks_ now last_due residual currentUrgency tasks =
    case tasks of
        task :: rest ->
            case Task.due task of
                Just dueDate ->
                    let
                        timeUntilDueInDays =
                            toFloat (Time.posixToMillis dueDate - Time.posixToMillis now) / 1000 / 60 / 60 / 24

                        timeUntilDueInDaysCapped =
                            max timeUntilDueInDays 1
                    in
                    if timeUntilDueInDays <= 0.0 then
                        let
                            newUrgency =
                                Task.duration task + currentUrgency

                            otherLabels =
                                labelTasks_ now now 0 newUrgency rest
                        in
                        { otherLabels | overdue = task :: otherLabels.overdue }

                    else if timeUntilDueInDays <= 1.0 then
                        let
                            newUrgency =
                                Task.duration task + currentUrgency

                            otherLabels =
                                labelTasks_ now dueDate 0 newUrgency rest
                        in
                        { otherLabels | doToday = task :: otherLabels.doToday }

                    else
                        let
                            addedResidual =
                                toFloat (Time.posixToMillis dueDate - Time.posixToMillis last_due) / 1000 / 60 / 60 / 24 * currentUrgency + residual
                        in
                        if addedResidual >= Task.duration task then
                            let
                                newResidual =
                                    addedResidual - Task.duration task

                                otherLabels =
                                    labelTasks_ now dueDate newResidual currentUrgency rest
                            in
                            { otherLabels | doLater = task :: otherLabels.doLater }

                        else
                            let
                                restOfTaskDuration =
                                    Task.duration task - addedResidual

                                newUrgency =
                                    currentUrgency + restOfTaskDuration / timeUntilDueInDaysCapped

                                otherLabels =
                                    labelTasks_ now dueDate 0 newUrgency rest
                            in
                            { otherLabels | doSoon = ( task, restOfTaskDuration / timeUntilDueInDaysCapped ) :: otherLabels.doSoon }

                Nothing ->
                    let
                        otherLabels =
                            labelTasks_ now last_due residual currentUrgency rest
                    in
                    { otherLabels | doLater = task :: otherLabels.doLater }

        [] ->
            { doLater = []
            , doToday = []
            , doSoon = []
            , overdue = []
            , done = []
            }


type Label
    = Overdue
    | DoToday
    | DoSoon
    | DoLater
    | Done


taskLabelWithId : LabeledTasks -> Id Task -> Label
taskLabelWithId taskLabels taskId =
    if List.any (Task.id >> (==) taskId) taskLabels.overdue then
        Overdue

    else if List.any (Task.id >> (==) taskId) taskLabels.doToday then
        DoToday

    else if List.any (Tuple.first >> Task.id >> (==) taskId) taskLabels.doSoon then
        DoSoon

    else if List.any (Task.id >> (==) taskId) taskLabels.doLater then
        DoLater

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
    if List.any taskHasParent taskLabels.overdue then
        Overdue

    else if List.any taskHasParent taskLabels.doToday then
        DoToday

    else if List.any (Tuple.first >> taskHasParent) taskLabels.doSoon then
        DoSoon

    else if List.any taskHasParent taskLabels.doLater then
        DoLater

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
