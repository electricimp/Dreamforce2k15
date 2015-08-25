// https://github.com/electricimp/salesforce/tree/v1.1.0
// https://github.com/electricimp/rocky/tree/v1.2.2
#require "Salesforce.class.nut:1.1.0"
#require "Rocky.class.nut:1.2.2"

//-------------------- Salesforce Constants --------------------//
const CLIENT_ID = "<-- CONSUMER-KEY -->";
const CLIENT_SECRET = "<-- CONSUMER-SECRET -->";
const LOGIN_HOST = "login.salesforce.com";



//---------- Extend Salesforce Class With Requests We Need ----------//
class ConnectedDevice extends Salesforce {

    agentId = split(http.agenturl(), "/").pop();

    function openCase(subject, description, cb = null) {
        local data = {
            "Subject": subject,
            "Description": description
        };
        
        this.request("POST", "sobjects/Case", http.jsonencode(data), cb);
    }
    
    function sendReading(data, cb = null) {
        local data = {
            "accel_x__c": data.accel_x,
            "accel_y__c": data.accel_y,
            "accel_z__c": data.accel_z
        }
        
        this.request("POST", "sobjects/Readings__c/DeviceId__c/" + agentId + "?_HttpMethod=PATCH", http.jsonencode(data), cb)
    }
}



//-------------------- Instante Salesforce --------------------//
force <- ConnectedDevice(CLIENT_ID, CLIENT_SECRET);

// Load existing credential data
oAuth <- server.load();

// If it exists, update the foce object
if ("instance_url" in oAuth && "access_token" in oAuth) {
    force.setInstanceUrl(oAuth.instance_url);
    force.setToken(oAuth.access_token);
    
    server.log("Loaded existing OAuth credentials.");
}



//-------------------- Application Code --------------------//
// Utility function to calculate the magnitude of a 3D vector
function get3DMagnitude(reading) {
    return math.sqrt((reading.x*reading.x) + (reading.y*reading.y) + (reading.z*reading.z));
}

// Update the device object in Salesforce each time we get a reading
device.on("accel", function(reading) {
    // If we're not logged in, do nothing
    if (!force.isLoggedIn()) return;
    
    local data = { 
        "accel_x": reading.x,
        "accel_y": reading.y,
        "accel_z": reading.z
    };
    
    force.sendReading(data, function(err, respData) {
        if (err) {
            server.error(http.jsonencode(err));
            return;
        }

        // Log a message if we created a new record
        if ("id" in respData) server.log("Created record with id: " + respData.id);
        else server.log("Updated record with DeviceId: " + force.agentId);
    }); 
});

// Create a new case in Salesforce each time there's an impact event
device.on("impact", function(data) {
    // If we're not logged in, do nothing
    if (!force.isLoggedIn()) return;

    local totalForce = get3DMagnitude(data);
    
    local subject = "Impact";
    local description = "AgentId: " + force.agentId + "\r\nTotal Force: " + totalForce;
    
    force.openCase(subject, description, function(err, data) {
        if (err) {
            server.error(http.jsonencode(err));
            return;
        }
        
        server.log("Created case with id: " + data.id);
    });
});



//-------------------- OAuth 2.0 Web Server Code --------------------//
app <- Rocky();

// When we receive a GET request to the agent URL
app.get("/", function(context) {
    // Check if an OAuth code was passed in
    if (!("code" in context.req.query)) {
        // If it wasn't, redirect to login service
        local location = format("https://%s/services/oauth2/authorize?response_type=code&client_id=%s&redirect_uri=%s", LOGIN_HOST, CLIENT_ID, http.agenturl());
        context.setHeader("Location", location);
        context.send(302, "Found");

        return;
    }

    // If it was, build a request to get the token
    local url = format("https://%s/services/oauth2/token", LOGIN_HOST);
    local headers = { "Content-Type": "application/x-www-form-urlencoded" };
    local body = http.urlencode({
        "code": context.req.query["code"],
        "grant_type": "authorization_code",
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "redirect_uri": http.agenturl()
    });

    // Send the request
    http.post(url, headers, body).sendasync(function(resp) {
        // Decode the body of the response
        local respData = http.jsondecode(resp.body);
        
        // If the request failed
        if (resp.statuscode != 200) {
            context.send(400, "Error authenticating (" + respData.error_description + ").");
            return;            
        }

        // If it was successful, save the data and and update salesforce
        server.save(respData);

        // Set the credentials in the Salesforce object
        force.setInstanceUrl(oAuth.instance_url);
        force.setToken(oAuth.access_token);

        // Finally - inform the user we're done! 
        context.send(200, "Authentication complete - you may now close this window");
    });
});

