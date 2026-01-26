import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import SliderControl from './SliderControl.vue'

describe('SliderControl', () => {
  it('renders with label', () => {
    const wrapper = mount(SliderControl, {
      props: {
        modelValue: 50,
        min: 0,
        max: 100,
        label: 'Test'
      }
    })
    expect(wrapper.text()).toContain('Test')
  })

  it('displays value with unit', () => {
    const wrapper = mount(SliderControl, {
      props: {
        modelValue: 300,
        min: 0,
        max: 2000,
        label: 'Delay',
        unit: 'ms'
      }
    })
    expect(wrapper.text()).toContain('300.0 ms')
  })

  it('displays value without unit when not provided', () => {
    const wrapper = mount(SliderControl, {
      props: {
        modelValue: 50,
        min: 0,
        max: 100,
        label: 'Test'
      }
    })
    expect(wrapper.text()).toContain('50.0')
    expect(wrapper.text()).not.toContain('ms')
    expect(wrapper.text()).not.toContain('%')
  })

  it('emits update on input', async () => {
    const wrapper = mount(SliderControl, {
      props: {
        modelValue: 50,
        min: 0,
        max: 100,
        label: 'Test'
      }
    })

    const input = wrapper.find('input[type="range"]')
    await input.setValue('75')

    expect(wrapper.emitted('update:modelValue')).toBeTruthy()
    expect(wrapper.emitted('update:modelValue')![0]).toEqual([75])
  })

  it('renders slider with correct min/max attributes', () => {
    const wrapper = mount(SliderControl, {
      props: {
        modelValue: 500,
        min: 0,
        max: 2000,
        label: 'Delay Time'
      }
    })

    const input = wrapper.find('input[type="range"]')
    expect(input.attributes('min')).toBe('0')
    expect(input.attributes('max')).toBe('2000')
  })

  it('calculates fill width correctly', () => {
    const wrapper = mount(SliderControl, {
      props: {
        modelValue: 50,
        min: 0,
        max: 100,
        label: 'Test'
      }
    })

    const fill = wrapper.find('.slider-fill')
    expect(fill.attributes('style')).toContain('width: 50%')
  })

  it('handles edge case: value at minimum', () => {
    const wrapper = mount(SliderControl, {
      props: {
        modelValue: 0,
        min: 0,
        max: 100,
        label: 'Test'
      }
    })

    const fill = wrapper.find('.slider-fill')
    expect(fill.attributes('style')).toContain('width: 0%')
  })

  it('handles edge case: value at maximum', () => {
    const wrapper = mount(SliderControl, {
      props: {
        modelValue: 100,
        min: 0,
        max: 100,
        label: 'Test'
      }
    })

    const fill = wrapper.find('.slider-fill')
    expect(fill.attributes('style')).toContain('width: 100%')
  })
})
