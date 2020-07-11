import React, {Component} from 'react';

import {Dropdown, Label} from 'semantic-ui-react';

const colors = [
  'Red',
  'Orange',
  'Yellow',
  'Olive',
  'Green',
  'Teal',
  'Blue',
  'Violet',
  'Purple',
  'Pink',
  'Brown',
  'Grey',
  'Black',
];

const colorOptions = colors.map(color => {
  return {
    key: color,
    text: color,
    value: color.toLowerCase(),
    label: {color: color.toLowerCase(), empty: true, circular: true},
  };
});

export default class ColorSelector extends Component{
  render = () => {
    return (
      <div>
        <Dropdown
          placeholder='Colour'
          defaultValue={this.props.defaultValue}
          search
          selection
          fluid
          className='icon'
          options={colorOptions}
          onChange={this.props.onChange}
        />
      </div>
    );
  };
}
