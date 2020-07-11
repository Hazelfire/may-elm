import React, {Component} from 'react';

import {Checkbox} from 'semantic-ui-react';

import moment from 'moment';

export default class NullableDateSelector extends Component {
  constructor(props) {
    super(props);

    this.state = {
      value: this.props.value
    };
  }

  onChecked = (event, data) => {
    let value = null;
    if(data.checked){
      value = this.props.defaultValue;
    }

    this.valueChange(value);
  }

  valueChange = (value) => {
    this.setState({value: value});
    if(this.props.onChange)
      this.props.onChange(value);
  }

  render = () => {
    let Child = React.cloneElement(React.Children.only(this.props.children), {
      value: this.props.value,
      onChange: this.valueChange
    });
    return (
      <div>
      <Checkbox defaultChecked={!!this.state.value} onChange={this.onChecked} label={this.props.label} />

      { this.state.value != null && 
        Child
      }
      </div>
    );
  }
}
