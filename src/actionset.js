import moment from 'moment';
import { createThunk, ERROR_SUFFIX, RESPONSE_SUFFIX } from './actions';
import ApiClient from './api';
import { selectUser } from './selectors';

const ADD_PREFIX = 'ADD_';
const DELETE_PREFIX = 'DELETE_';
const EDIT_PREFIX = 'EDIT_';
const LIST_PREFIX = 'LIST_';

const DEFAULT_OBJECT_STATUS = {
  delete: {
    loading: false,
    error: undefined,
  },

  edit: {
    loading: false,
    error: undefined,
  },

  add: {
    loading: false,
    error: undefined,
  },
};

export class ResourceState {
  constructor(state) {
    if (state === undefined) {
      state = {
        objects: [],
        status: {
          list: {
            loading: false,
            error: undefined,
          },
        },
      };
    }
    this.state = state;
  }

  setListStatus(loading, error) {
    let state = this.state;
    this.state = {
      ...state,
      status: {
        ...state.status,
        list: {
          loading,
          error,
        },
      },
    };
  }

  getListStatus() {
    return this.state.status.list;
  }

  setObjects(objects) {
    let state = this.state;
    this.state = {
      ...state,
      objects: objects.map(object => ({
        object,
        status: DEFAULT_OBJECT_STATUS,
      })),
    };
  }

  deleteWithId(id) {
    let state = this.state;
    this.state = {
      ...state,
      objects: state.objects.filter(object => object.object.id != id),
    };
  }

  operateObject(id, func) {
    let state = this.state;
    this.state = {
      ...state,
      objects: state.objects.map(item => {
        if (id === item.object.id) {
          return func(item);
        } else {
          return item;
        }
      }),
    };
  }

  deleteWithId(id) {
    let state = this.state;
    this.state = {
      status: state.status,
      objects: state.objects.filter(object => object.object.id != id),
    };
  }

  setObjectStatus(id, status) {
    this.operateObject(id, object => {
      return {
        ...object,
        status: {
          ...DEFAULT_OBJECT_STATUS,
          ...status,
        },
      };
    });
  }

  getObjectWithId(id) {
    return this.state.objects.find(object => object.object.id == id);
  }

  getObjectStatus(id) {
    return this.getObjectWithId(id).status;
  }

  setObjectDeleteStatus(id, loading, error) {
    this.setObjectStatus(id, {
      delete: { loading, error },
    });
  }

  addObject(object) {
    let state = this.state;
    this.state = {
      objects: state.objects.concat([
        { object, status: DEFAULT_OBJECT_STATUS },
      ]),
      status: state.status,
    };
  }

  setObjectAddStatus(id, loading, error) {
    this.setObjectStatus(id, {
      add: { loading, error },
    });
  }

  editObject(id, patches) {
    this.operateObject(id, object => {
      return {
        ...object,
        object: {
          ...object.object,
          ...patches,
        },
      };
    });
  }

  setObjectEditStatus(id, loading, error) {
    this.setObjectStatus(id, {
      edit: { loading, error },
    });
  }

  toList() {
    return this.state.objects.map(object => object.object);
  }

  toObject() {
    return this.state;
  }
}

export class ActionSet {
  constructor(endpoint, name, serialiser, defaultObjects) {
    this.endpoint = endpoint;
    this.name = name;
    this.serialiser = serialiser;
    this.listeners = [];
    if (defaultObjects) {
      this.default = defaultObjects;
    } else {
      this.default = [];
    }
    this.list = createThunk(
      LIST_PREFIX + this.name,
      () => async (dispatch, getState) => {
        let api = new ApiClient(selectUser(getState()));
        let items = await api.listAt(this.endpoint);
        return items.map(item => this.serialiser.toInternal(item));
      },
      () => ({ set: this.name })
    );

    this.add = createThunk(
      ADD_PREFIX + this.name,
      object => async (dispatch, getState) => {
        let api = new ApiClient(selectUser(getState()));
        return await api.addAt(
          this.endpoint,
          this.serialiser.toNetwork(object)
        );
      },
      object => ({
        item: object,
        set: this.name,
        time: moment().unix(),
      })
    );

    this.delete = createThunk(
      DELETE_PREFIX + this.name,
      id => async (dispatch, getState) => {
        let api = new ApiClient(selectUser(getState()));
        return await api.deleteAt(this.endpoint, id);
      },
      id => ({ id, set: this.name })
    );

    this.edit = createThunk(
      EDIT_PREFIX + this.name,
      (id, patches) => async (dispatch, getState) => {
        let api = new ApiClient(selectUser(getState()));
        return await api.editAt(
          this.endpoint,
          id,
          this.serialiser.toNetwork(patches)
        );
      },
      (id, patches) => ({ id, patches, set: this.name })
    );
  }

  addListener(listener) {
    this.listeners.push(listener);
  }

  empty() {
    let resourceState = new ResourceState();
    resourceState.setObjects(this.default);
    return resourceState.toObject();
  }

  reducer() {
    return (state, action) => {
      let resourceState = new ResourceState(state);

      if (!state) {
        resourceState.setObjects(this.default);
      }

      let id;
      switch (action.type) {
        /* List Actions */
        case LIST_PREFIX + this.name:
          resourceState.setListStatus(true, undefined);
          break;

        case LIST_PREFIX + this.name + RESPONSE_SUFFIX:
          resourceState.setListStatus(false, undefined);
          resourceState.setObjects(action.response);
          break;

        case LIST_PREFIX + this.name + ERROR_SUFFIX:
          resourceState.setListStatus(false, action.error);
          break;

        /* Delete Actions */
        case DELETE_PREFIX + this.name:
          resourceState.setObjectDeleteStatus(action.id, true, undefined);
          break;

        case DELETE_PREFIX + this.name + RESPONSE_SUFFIX:
          resourceState.deleteWithId(action.original.id);
          break;

        case DELETE_PREFIX + this.name + ERROR_SUFFIX:
          resourceState.setObjectDeleteStatus(
            action.original.id,
            false,
            action.error
          );
          if (action.error.doLocally) {
            resourceState.deleteWithId(action.original.id);
          }
          break;

        /* Add Actions */
        case ADD_PREFIX + this.name:
          resourceState.addObject({
            ...action.item,
            id: action.time,
          });
          resourceState.setObjectAddStatus(action.time, true, undefined);
          break;

        case ADD_PREFIX + this.name + RESPONSE_SUFFIX:
          id = action.response.id;
          resourceState.editObject(action.original.time, {
            id,
          });
          resourceState.setObjectAddStatus(id, false, undefined);
          break;

        case ADD_PREFIX + this.name + ERROR_SUFFIX:
          id = action.original.time;
          resourceState.setObjectAddStatus(id, false, action.error);
          break;

        /* Edit actions */
        case EDIT_PREFIX + this.name:
          resourceState.setObjectEditStatus(action.id, true, undefined);
          break;

        case EDIT_PREFIX + this.name + RESPONSE_SUFFIX:
          id = action.original.id;
          resourceState.setObjectEditStatus(id, false, undefined);
          resourceState.editObject(id, action.original.patches);
          break;

        case EDIT_PREFIX + this.name + ERROR_SUFFIX:
          id = action.original.id;
          resourceState.setObjectEditStatus(id, false, action.error);
          if (action.error.doLocally) {
            resourceState.editObject(id, action.original.patches);
          }
          break;
      }

      this.listeners.reduce(
        (resourceState, listener) => listener(resourceState, action),
        resourceState
      );
      return resourceState.toObject();
    };
  }
}
