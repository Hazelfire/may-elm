import moment from 'moment';
import { createSelector } from 'reselect';
import { ResourceState } from './actionset';

export const getTasksResource = state =>
  new ResourceState(state.serverReducer.tasks);
export const getTasks = state => getTasksResource(state).toList();
export const getTime = state => state.serverReducer.time;
export const getSelectedFolderId = state => state.selection.selectedFolder;
export const getSelectedId = state => state.selection.selected;
export const getFolders = state =>
  new ResourceState(state.serverReducer.folders).toList();
export const getGuestMode = state => !state.login.user;

function removeDuplicateTasks(tasks) {
  return tasks.filter(
    (task, index) =>
      !tasks.find(
        (searchTask, searchIndex) =>
          searchIndex > index && task.id === searchTask.id
      )
  );
}

function getWithIds(allTasks, taskIds) {
  return allTasks.filter(task => taskIds.includes(task.id));
}

function taskChildren(task, allTasks) {
  if (task.dependencies) {
    let children = getWithIds(allTasks, task.dependencies);
    return removeDuplicateTasks(
      children.flatMap(task => taskChildren(task, allTasks))
    ).concat([task]);
  } else {
    return [task];
  }
}

function taskUrgency(task, time, due) {
  if (!task.done && (due || task.due)) {
    let days = moment
      .duration(moment(due ? due : task.due).diff(moment.unix(time)))
      .asDays();
    if (days > 0) {
      return task.duration / days;
    } else {
      return Infinity;
    }
  } else {
    return 0;
  }
}

function getTaskById(allTasks, id) {
  return allTasks.find(task => task.id === id);
}

function taskChainedUrgency(task, time, allTasks, due, ancestors) {
  let urgency = taskUrgency(task, time, due);
  let currentTask = task;
  let ancestorId;
  while ((ancestorId = ancestors.get(currentTask.id))) {
    currentTask = getTaskById(allTasks, ancestorId);
    urgency += taskUrgency(currentTask, time, due);
  }
  return urgency;
}

function taskVelocity(task, time, due) {
  if (!task.done && (due || task.due)) {
    let days = moment
      .duration(moment(due ? due : task.due).diff(moment.unix(time)))
      .asDays();
    if (days > 0) {
      return task.duration / days / days;
    } else {
      return Infinity;
    }
  } else {
    return 0;
  }
}

function getDueDateMapping(tasks) {
  let dueDateMap = new Map();

  let heads = tasks.filter(task => task.due);
  let childrenPairs = heads.map(task => [task.due, taskChildren(task, tasks)]);

  for (let childPair of childrenPairs) {
    let dueDate = childPair[0];
    let children = childPair[1];

    for (let child of children) {
      let currentDueDate = dueDateMap.get(child.id);
      if (currentDueDate) {
        if (currentDueDate > dueDate) {
          dueDateMap.set(child.id, dueDate);
        }
      } else {
        dueDateMap.set(child.id, dueDate);
      }
    }
  }
  return dueDateMap;
}

export const calculateListUrgency = createSelector(
  [getTasks, getTime],
  (tasks, time) => {
    let tasksNotDone = tasks.filter(task => !task.done);
    let dueDateMap = getDueDateMapping(tasks);

    return tasksNotDone.reduce(
      (sum, task) => sum + taskUrgency(task, time, dueDateMap.get(task.id)),
      0
    );
  }
);

export const calculateListVelocity = createSelector(
  getTasks,
  getTime,
  (tasks, time) => {
    let tasksNotDone = tasks.filter(task => !task.done);
    let dueDateMap = getDueDateMapping(tasks);

    return tasksNotDone.reduce(
      (sum, task) => sum + taskVelocity(task, time, dueDateMap.get(task.id)),
      0
    );
  }
);

export const urgencyForEach = createSelector(
  [getTasks, getTime],
  (tasks, time) => {
    let dueDateMap = getDueDateMapping(tasks);
    let ancestors = getAncestorRelationships(tasks);

    return tasks.map(task => {
      let urgency;
      let impliedDue = dueDateMap.get(task.id);
      if (task.done) urgency = 0;
      else
        urgency = taskChainedUrgency(task, time, tasks, impliedDue, ancestors);
      return { ...task, urgency: urgency, impliedDue };
    });
  }
);

function getAncestorRelationships(tasks) {
  let relationships = [];
  for (let task of tasks) {
    let newRelationships = task.dependencies.map(dependency => [
      dependency,
      task.id,
    ]);
    relationships = relationships.concat(newRelationships);
  }
  return new Map(relationships);
}

export const calculateTodoOrder = createSelector(
  urgencyForEach,
  tasks =>
    tasks
      .filter(task => !task.done && (task.urgency > 0 || task.due))
      .sort((a, b) => b.urgency - a.urgency)
);

export const calculateListBait = createSelector(
  urgencyForEach,
  tasks => {
    let tasksWithUrgency = tasks.filter(
      task => !task.done && (task.urgency > 0 || task.due)
    );
    let sortedTasks = tasksWithUrgency.sort((a, b) => b.urgency - a.urgency);
    let tasksWithoutFirst = sortedTasks.filter((task, index) => index > 0);
    return tasksWithoutFirst.reduce((sum, task) => sum + task.urgency, 0);
  }
);

export const getTasksInSelectedFolder = createSelector(
  [getFolders, urgencyForEach, getSelectedFolderId],
  (folders, tasks, folderId) => {
    if (!folderId) {
      let rootFolder = folders.find(folder => folder.root);
      if (rootFolder) {
        folderId = rootFolder.id;
      }
    }
    return tasks.filter(task => task.parent == folderId);
  }
);

export const getTasksRecursiveInSelectedFolder = createSelector(
  [getFolders, urgencyForEach, getSelectedFolderId],
  (folders, tasks, folderId) => {}
);

export const getFoldersInSelectedFolder = createSelector(
  [getFolders, getSelectedFolderId],
  (folders, folderId) => {
    if (!folderId) {
      let rootFolder = folders.find(folder => folder.root);
      if (rootFolder) {
        folderId = rootFolder.id;
      }
    }
    return folders.filter(folders => folders.parent == folderId);
  }
);

export const getSelectedFolder = createSelector(
  [getFolders, getSelectedFolderId],
  (folders, folderId) => {
    if (!folderId) {
      return folders.find(folder => folder.root);
    } else {
      return folders.find(folder => folder.id == folderId);
    }
  }
);

const folderUrgency = (folder, folders, tasks, time) => {
  let childTasks = tasks.filter(task => task.parent == folder.id);
  let urgency = childTasks.reduce(
    (sum, child) => sum + taskUrgency(child, time),
    0
  );

  let childFolders = folders.filter(
    possibleChild => possibleChild.parent == folder.id
  );
  return childFolders.reduce(
    (sum, child) => sum + folderUrgency(child, folders, tasks, time),
    urgency
  );
};

const folderVelocity = (folder, folders, tasks, time) => {
  let childTasks = tasks.filter(task => task.parent == folder.id);
  let urgency = childTasks.reduce(
    (sum, child) => sum + taskVelocity(child, time),
    0
  );

  let childFolders = folders.filter(
    possibleChild => possibleChild.parent == folder.id
  );
  return childFolders.reduce(
    (sum, child) => sum + folderVelocity(child, folders, tasks, time),
    urgency
  );
};

export const getSelected = createSelector(
  [getTasks, getFolders, getSelectedId, getTime],
  (tasks, folders, selected, time) => {
    let task = tasks.find(task => task.id == selected);
    let dueDateMap = getDueDateMapping(tasks);
    if (task) {
      return {
        ...task,
        type: 'task',
        urgency: taskUrgency(task, time, dueDateMap.get(task.id)),
        velocity: taskVelocity(task, time, dueDateMap.get(task.id)),
      };
    } else {
      let folder = folders.find(folder => folder.id == selected);
      if (folder) {
        return {
          ...folder,
          type: 'folder',
          urgency: folderUrgency(folder, folders, tasks, time),
          velocity: folderVelocity(folder, folders, tasks, time),
        };
      }
    }
  }
);

export const getTasksInFolder = (folderId, state) => {
  let folders = getFolders(state);
  let tasks = getTasks(state);
  if (!folderId) {
    let rootFolder = folders.find(folder => folder.root);
    if (rootFolder) {
      folderId = rootFolder.id;
    }
  }
  return tasks.filter(task => task.parent == folderId);
};

export const getFoldersInFolder = (folderId, state) => {
  let folders = getFolders(state);
  if (!folderId) {
    let rootFolder = folders.find(folder => folder.root);
    if (rootFolder) {
      folderId = rootFolder.id;
    }
  }
  return folders.filter(folders => folders.parent == folderId);
};

export const selectUser = state => state.login.user;
