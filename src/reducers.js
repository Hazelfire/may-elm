/* Redux Reducers. These are begging to be turned functional.
 * 
 * This module is going through a refactor, the comment at the bottom indicates
 * what was before the refactor. This reducers file now better implements an
 * elm like architecture.
 *
 * All of the functions exported here are combined with combineReducers. The
 * names of the functions are important, because they represent what keys the
 * reducer applies to
 *
 * */
import {
  SELECT,
  LOGIN,
  TOKEN_LOGIN,
  LOGOUT,
  REGISTER,
  RESPONSE_SUFFIX,
  ERROR_SUFFIX,
  SET_TIME,
  SET_FOLDER,
} from './actions';
import { taskset, folderset, labelset } from './actions';
import moment from 'moment';

// Main function, call this to get new state
export default (action, state) => {
  if(action.type in actionMapping){
    return actionMapping[action.type](action,state) 
  }
  else {
    console.log("COULD NOT FIND HANDLER FOR ACTION")
    console.log(action)
    return state;
  }
} 

function generateID(){
  return new Date().getTime();
}


let addTask = (action, state) => {
  let task = action.task;
  let newTask = {
    ...task, 
    parent: state.currentFolder.id,
    id: generateID()
  }
  return {
    ...state,
    tasks: state.tasks.concat([newTask])
  };
};


let editTask = (action, state) => {
  let {task,changes} = action;
  return {
    tasks: state.tasks.map(t => {
      if(t.id === task.id){
         return { ...t, ...changes};
      }
      return t;
    })
  };
}


let deleteTask = (action, state) => {
  let {task} = action;
  return {
    ...state,
    tasks: state.tasks.filter(t => t.id !== task.id)
  };
}

let addLabel = (action, state) => {
  let { label } = action;
  let newLabel  = {
    ...label,
    id: generateID()
  }
  return {
    ...state,
    labels: state.labels.concat([newLabel])
  };
};

let editLabel = (action, state) => {
  let {label,changes} = action;
  return {
    labels: state.labels.map(l => {
      if(l.id === label.id){
         return { ...l, ...changes};
      }
      return l;
    })
  };
}

let deleteLabel = (action, state) => {
  let {label} = action;
  return {
    ...state,
    labels: state.labels.filter(l => l.id !== label.id)
  };
}


let deleteFolder = (action,state) => {
  let folder = action.folder;
  return {
    ...state,
    folders: state.folders.filter(f => f.id !== folder.id)
  };
}

let editFolder = (action, state) => {
  let folder = action.folder;
  let changes = action.changes;
  return {
    ...state,
    folders: state.folders.map(f => {
      if(f.id === folder.id){
         return { ...f, ...changes};
      }
      return f;
    })
  };
}
let setFolder = (action, state) => {
  let {folder} = action;
  return {
    ...state,
    currentFolder: folder
  };
}

let addFolder = (action, state) => {
  let folder = action.folder;
  let newFolder = {
    ...folder, 
    parent: state.currentFolder.id,
    id: generateID()
  }
  return {
    ...state,
    folders: state.folders.concat([newFolder])
  };
};

const actionMapping = { 
  ADD_TASK: addTask,
  EDIT_TASK: editTask,
  DELETE_TASK: deleteTask,
  ADD_LABEL: addLabel,
  EDIT_LABEL: editLabel,
  DELETE_LABEL: deleteLabel,
  SET_FOLDER: setFolder,
  EDIT_FOLDER: editFolder,
  ADD_FOLDER: addFolder,
  DELETE_FOLDER: deleteFolder
}
// Anything below this line was before the refactor

export let login = (state = {}, action) => {
  switch (action.type) {
    case LOGIN:
      return { ...state, loading: true };
    case REGISTER + RESPONSE_SUFFIX:
    case LOGIN + RESPONSE_SUFFIX:
      localStorage.setItem('user', JSON.stringify(action.response));
      return {
        ...state,
        user: action.response,
        isSignedIn: true,
        loading: false,
      };
    case LOGIN + ERROR_SUFFIX:
      return {
        ...state,
        loginErrors: action.error,
        isSignedIn: false,
        loading: false,
      };
    case TOKEN_LOGIN:
      if (action.user) {
        return { ...state, user: action.user, isSignedIn: true };
      } else {
        return state;
      }
    case LOGOUT:
      localStorage.removeItem('user');
      return { ...state, user: undefined, isSignedIn: false, loading: false };
    default:
      return state;
  }
};

export let register = (
  state = {
    loading: false,
    registered: false,
  },
  action
) => {
  switch (action.type) {
    case REGISTER:
      return {
        ...state,
        loading: true,
      };
      break;
    case REGISTER + RESPONSE_SUFFIX:
      return {
        ...state,
        loading: false,
        registered: true,
        errors: undefined,
      };
      break;
    case REGISTER + ERROR_SUFFIX:
      return {
        ...state,
        loading: false,
        errors: action.error,
      };
      break;
  }
  return state;
};

export let selection = (state = {}, action) => {
  switch (action.type) {
    case TOKEN_LOGIN + RESPONSE_SUFFIX:
      result = {
        ...state,
        tasks: action.response.tasks,
        loading: false,
      };
      break;
    case SET_FOLDER:
      return {
        ...state,
        selectedFolder: action.id,
        selected: undefined,
      };
      break;
    case SELECT:
      return {
        ...state,
        selected: action.id == state.selected ? undefined : action.id,
      };
      break;
  }

  return state;
};

export let serverReducer = (
  state = {
    loading: false,
  },
  action
) => {
  let result = { ...state };
  result.tasks = taskset.reducer()(state.tasks, action);
  result.folders = folderset.reducer()(state.folders, action);
  result.labels = labelset.reducer()(state.labels, action);

  if (action.type == LOGOUT) {
    result.tasks = taskset.empty();
    result.folders = folderset.empty();
    result.labels = labelset.empty();
  }

  if (action.time) {
    result.time = action.time;
  }

  return result;
};
