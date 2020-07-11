import { backend } from './config';

export default class ApiClient {
  constructor(user, hostname = backend) {
    this.user = user;
    this.hostname = hostname;
  }

  static async logIn(username, password, endpoint = backend) {
    let data = new URLSearchParams();
    data.append('username', username);
    data.append('password', password);

    let response = await fetch(endpoint + '/auth/login/', {
      method: 'POST',
      headers: new Headers({
        'X-CSRFToken': ApiClient.getCookie('csrftoken'),
        'Content-Type': 'application/x-www-form-urlencoded',
      }),
      body: data,
    });
    let json = await response.json();
    if (!json.key) {
      throw json;
    }

    return {
      token: json.key,
      username: username,
    };
  }

  async logOut() {
    let token = this.user.token;
    await fetch(this.hostname + '/auth/logout/', {
      method: 'POST',
      headers: new Headers({
        Authorization: 'Token ' + token,
        'X-CSRFToken': ApiClient.getCookie('csrftoken'),
      }),
      body: JSON.stringify({}),
    });
  }

  static async register(
    username,
    password,
    confirm,
    email,
    endpoint = backend
  ) {
    let data = new URLSearchParams();
    data.append('username', username);
    data.append('password1', password);
    data.append('password2', confirm);
    data.append('email', email);

    let response = await fetch(endpoint + '/auth/registration/', {
      method: 'POST',
      headers: new Headers({
        'X-CSRFToken': ApiClient.getCookie('csrftoken'),
        'Content-Type': 'application/x-www-form-urlencoded',
      }),
      body: data,
    });
    let json = await response.json();
    if (!json.key) {
      throw json;
    }
    return {
      token: json.key,
      username: username,
    };
  }

  listAt = async endpoint => {
    let token = this.user.token;

    let response = await fetch(this.hostname + endpoint, {
      headers: new Headers({
        Authorization: 'Token ' + token,
        'X-CSRFToken': ApiClient.getCookie('csrftoken'),
      }),
    });
    return await response.json();
  };

  addAt = async (endpoint, object) => {
    let token = this.user.token;

    let response = await fetch(this.hostname + endpoint, {
      method: 'POST',
      headers: new Headers({
        Authorization: 'Token ' + token,
        'X-CSRFToken': ApiClient.getCookie('csrftoken'),
        'Content-Type': 'application/json',
      }),
      body: JSON.stringify(object),
    });

    return await response.json();
  };

  deleteAt = async (endpoint, id) => {
    let token = this.user.token;

    await fetch(this.hostname + endpoint + id + '/', {
      method: 'DELETE',
      headers: new Headers({
        Authorization: 'Token ' + token,
        'X-CSRFToken': ApiClient.getCookie('csrftoken'),
      }),
    });
  };

  editAt = async (endpoint, id, patches) => {
    let token = this.user.token;

    await fetch(this.hostname + endpoint + id + '/', {
      method: 'PATCH',
      headers: new Headers({
        Authorization: 'Token ' + token,
        'X-CSRFToken': ApiClient.getCookie('csrftoken'),
        'Content-Type': 'application/json',
      }),
      body: JSON.stringify(patches),
    });
  };

  static getCookie(name) {
    var cookieValue = null;
    if (document.cookie && document.cookie !== '') {
      var cookies = document.cookie.split(';');
      for (var i = 0; i < cookies.length; i++) {
        var cookie = cookies[i].trim();
        // Does this cookie string begin with the name we want?
        if (cookie.substring(0, name.length + 1) === name + '=') {
          cookieValue = decodeURIComponent(cookie.substring(name.length + 1));
          break;
        }
      }
    }
    return cookieValue;
  }
}
