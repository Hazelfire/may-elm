import React, {Component} from 'react';

import {Checkbox} from 'semantic-ui-react';
import 'flatpickr/dist/themes/material_green.css';
import NullableField from './NullableField';

import Flatpickr from 'react-flatpickr';

import moment from 'moment';

export default class NullableDateSelector extends Component {
  constructor(props) {
    super(props);

    this.state = {
      date: null
    };

    if(this.props.defaultValue){
      this.state.date = this.props.defaultValue;
    }

  }

  // Sets the date in state and informs parent
  dateChange = (date) => {
    if(date === null){
      this.setState({date: null});
      if(this.props.onChange)
        this.props.onChange(date);
    }
    else{
      this.setState({date: date[0]});
      if(this.props.onChange)
        this.props.onChange(date[0].toISOString());
    }
  }

  render = () => {
    return (
      <NullableField value={this.state.date} onChange={this.dateChange} label="Does this task have a due date?" defaultValue={[new Date()]}>
        <Flatpickr data-enable-time />
      </NullableField>
    );
  }
}
