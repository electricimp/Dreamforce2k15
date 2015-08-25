// https://github.com/electricimp/LSM9DS0/tree/v1.1
#require "LSM9DS0.class.nut:1.1.0"

//-------------------- Hardware Configuration --------------------//
// Configure the I2C bus we're using
i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

// IMU = Intertial Measurment Unit
imu <- LSM9DS0(i2c);

// Enable the Accelerometer
imu.setEnable_A(1);
// Set data rate (10 readings/second)
imu.setDatarate_A(10);



//-------------------- Live Update Code --------------------//
// Take a reading from the accelerometer every 15 seconds and send to agent
function poll() {
    // Schedule next reading
    imp.wakeup(1, poll);
    
    // Read the accelerometer
    local accelData = imu.getAccel();
    // Send the data to the agent
    agent.send("accel", accelData);
}

poll();



//-------------------- Impact Code --------------------//
// Configure Interrupts
imu.setInertInt1En_P1(1);   // Enable the intertial interrupt generator
imu.setIntActivehigh_XM();  // Set to active high (pin goes high on event)

imu.setInt1Duration_A(1);   // Generate interrupt if 1 or more reading above the threshold
imu.setInt1Ths_A(1.5);      // Set the threshold to 1.5G

// Configure the interrupt pin
xm_int1 <- hardware.pin2;
xm_int1.configure(DIGITAL_IN, function() {
    // Ignore falling edges (otherwise we would get 2 events per impact)
    if (!xm_int1.read()) return;
    
    // Read the current acceleration
    local accel = imu.getAccel();
    // Send the data to the agent
    agent.send("impact", accel);

    // Clear the internal interrupt flag by reading the Int1Src register
    imu.getInt1Src_XM();
});

