# Whack-A-Mole Game

## Overview
The Whack-A-Mole game is implemented using two approaches: **Polling** and **Interrupts**. The game leverages the ARM A9 private timer, pushbuttons, slider switches, and HEX displays to provide a timed interactive experience. The goal is to hit the mole as it appears on random HEX displays while tracking the score.

---

## Approach: Polling

### Timer Configuration
- The timer control register is set to `0x0000fa03`, enabling the timer with a prescaler value of `0xfa` (250 in decimal).
- With a clock frequency of 200 MHz, the timer decrements every 250 clock cycles, corresponding to 1.25 μs per decrement.
- The timer is loaded with `80,000` for a countdown of 0.1 seconds, achieving the required timing for the game.

### Implementation Steps

1. **Game Setup**:
   - The game is initialized with the `reset` subroutine, which clears the HEX displays and loads initial values.
   - A3 (score counter) is initialized to 0.
   - The program polls the edgecapture register until PB0 (start) is pressed to begin the game.

2. **Timer Polling**:
   - The `one_second` subroutine polls the F bit in the interrupt status register to detect when the timer reaches 0.
   - The timer reloads the load value automatically (A bit set to 1) to avoid delays.
   - The last three bits of the timer value are masked to determine the next mole position.
   - The interrupt status register is cleared.

3. **Time Display**:
   - The time remaining is displayed on HEX4 and HEX5.
   - If the time is less than 10 seconds, tenths of a second are displayed on the 5th HEX display.

4. **Game Progression**:
   - If the timer reaches 0, the program ends, and the final score (A3) is displayed.
   - If PB2 (reset) is pressed, the game restarts through the `reset` subroutine.
   - If PB1 (stop) is pressed, the game enters a halt state until PB0 (start) or PB2 (reset) is pressed.

5. **Hit Detection**:
   - The `check_hit` subroutine validates inputs from the slider switches.
   - If multiple switches are pressed simultaneously, the input is ignored.
   - A valid hit increments A3 (score).

6. **Random Mole Placement**:
   - The mole position is randomized using the timer value, ensuring it avoids HEX displays where switches are already set.

---

## Approach: Interrupts

### Timer and Pushbutton Interrupts
- The timer control register is set to `0x000fa07`, enabling interrupts (I bit set to 1) and the timer’s countdown behavior.
- The Generic Interrupt Controller (GIC) is configured to handle interrupts with unique IDs:
  - **KEY_ISR**: Handles pushbutton interrupts for game control (start, stop, reset).
  - **ARM_TIM_ISR**: Handles timer interrupts to update time and mole position.

### Implementation Steps

1. **Game Setup**:
   - Similar to the polling approach, the `reset` subroutine initializes the game.

2. **Interrupt Handling**:
   - **KEY_ISR**:
     - Detects the pushbutton pressed and determines the action (start, stop, reset, or continue).
   - **ARM_TIM_ISR**:
     - Detects when the timer reaches 0 and updates the timer value and mole position.

3. **Random Mole Placement**:
   - Mole placement uses the same logic as in the polling approach, leveraging the timer value for randomization.

4. **Game Progression**:
   - The game proceeds similarly to the polling version but relies on interrupts for timer and pushbutton events.

---

## Testing
1. **Game Start**:
   - Tested by pressing PB0 to ensure the timer starts and mole appears on a HEX display.
2. **Mid-Game Reset**:
   - Verified that pressing PB2 resets the game, clearing the displays and score.
3. **Stop and Restart**:
   - Ensured that pressing PB1 halts the game and PB0 restarts it.
4. **Game Completion**:
   - Confirmed that the final score is displayed when the timer reaches 0.
5. **Invalid Inputs**:
   - Checked that simultaneous switch presses are ignored.
6. **Simulator**:
   - https://ecse324.ece.mcgill.ca/simulator/?sys=arm-de1soc

---

## Shortcomings and Improvements

1. **Polling Inefficiency**:
   - Polling results in higher instruction counts and data loads/stores, impacting performance.
   - **Executed Instructions**: 243,189,295
   - **Data Loads**: 28,061,732
   - **Data Stores**: 14,012

2. **Interrupt Efficiency**:
   - Interrupts reduce the number of executed instructions and data accesses, improving performance.
   - **Executed Instructions**: 193,853,669
   - **Data Loads**: 93,112,638
   - **Data Stores**: 74,713,133

3. **Optimizations**:
   - Using interrupts reduces CPU load but still results in high instruction counts. Further optimization of interrupt handlers could minimize processing time.

4. **Potential Enhancements**:
   - Improve randomization by introducing additional entropy sources.
   - Use optimized data structures to handle mole position and switch states more efficiently.
   - Reduce timer setup overhead by preloading values during initialization.

