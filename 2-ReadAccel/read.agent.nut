//-------------------- Application Code --------------------//
// Utility function to calculate the magnitude of a 3D vector
function get3DMagnitude(reading) {
    return math.sqrt((reading.x*reading.x) + (reading.y*reading.y) + (reading.z*reading.z));
}

// When we get a reading, log it
device.on("accel", function(reading) {
    // Calculate the total force
    local totalForce = get3DMagnitude(reading);
    
    // Log a message
    server.log("Got a reading: " + totalForce + "G (X: " + reading.x + ", Y: " + reading.y + ", " + reading.z + ")");
});

// When we get an impact event, log it
device.on("impact", function(data) {
    // Calculate the total force
    local totalForce = get3DMagnitude(data);
    
    // Log a message
    server.log("Impact Event (" + totalForce + "G)");
});

