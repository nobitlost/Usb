# Usb Drivers

The USB libary acts as a wrapper around the Imp API `hardware.usb` object and manages USB device connections, disconnections, transfers and driver selection.

**To use this library add the following statement to the top of your device code:**

```
#require "USB.device.lib.nut:0.1.0"
```

## USB.Host

The USB.Host class has methods to subsicribe to events and register drivers (see [USB.DriverBase](#USBDriver) for more details on USB drivers).

### Class Usage

#### Constructor: USB.Host(*usb[, autoConfigPins]*)

Instantiates the USB.Host class. It takes `hardware.usb` as a required parameter and an optional boolean flag.

| Parameter 	 | Data Type | Default | Description |
| -------------- | --------- | ------- | ----------- |
| *usb* 		 | Object 	 | n/a 	   | The imp API hardware usb object `hardware.usb` |
| *autoConfPins* | Boolean   | `true`  | Whether to configure pin R and W according to [electric imps docs](https://electricimp.com/docs/hardware/imp/imp005pinmux/#usb). These pins must be configured for the usb to work on an imp005. |

##### Example

```squirrel
usbHost <- USB.Host(hardware.usb);
```

### Class Methods

#### registerDriver(*driverClass, identifiers*)

Registers a driver to a devices list of VID/PID combinations. When a device is connected via usb its VID/PID combination will be looked up and the matching driver will be instantiated to interface with device.


| Parameter 	| Data Type | Required | Description |
| ------------- | --------- | -------- | ----------- |
| *driverClass* | Class 	| Yes 	   | A reference to the class to be instantiated when a device with matching identifiers is connected. Must be a valid usb driver class that extends the *USB.DriverBase* class. |
| *identifiers* | Array 	| Yes 	   | Array of VID/PID combinations. When a device connected that identifies itself with any of the PID/VID combinations provided the *driverClass* will be instatiated.


##### Example

```squirrel
// Register the Ftdi driver with usb host
usbHost.registerDriver(FtdiUsbDriver, FtdiUsbDriver.getIdentifiers());
```

#### on(*eventName, callback*)

Subscribe a callback function to a specific event. There are currently 2 events that you can subscibe to `"connected"` and `"disconnected"`.


| Parameter   | Data Type | Required | Description |
| ----------- | --------- | -------- | ----------- |
| *eventName* | String 	  | Yes 	 | The string name of the event to subscribe to |
| *callback*  | Function  | Yes 	 | Function to be called on event |

##### Example

```squirrel
// Subscribe to usb connection events
usbHost.on("connected",function (device) {
    server.log(typeof device + " was connected!");
    switch (typeof device) {
        case "FtdiUsbDriver":
            // device is a ftdi device. Handle it here.
            break;
    }
});

// Subscribe to usb disconnection events
usbHost.on("disconnected",function(deviceName) {
    server.log(deviceName + " disconnected");
});

```

#### off(*eventName*)

Clears a subscribed callback function from a specific event.

| Parameter   | Data Type | Required | Description |
| ----------- | --------- | -------- | ----------- |
| *eventName* | String    | Yes      | The string name of the event to unsubscribe from |

##### Example

```squirrel
// Subscribe to usb connection events
usbHost.on("connected",function (device) {
    server.log(typeof device + " was connected!");
    switch (typeof device) {
        case "FtdiUsbDriver":
            // device is a ftdi device. Handle it here.
            break;
    }
});

// Unsubscribe from usb connection events after 30 seconds
imp.wakeup(30,function(){
	usbHost.off("connected");
}.bindenv(this))
```


#### getDriver()

Returns the driver for the currently connected devices. Returns `null` if no device is connected or a corresponding driver to the device was not found.

##### Example

```squirrel
// Register the Ftdi driver with usb host
usbHost.registerDriver(FtdiUsbDriver, FtdiUsbDriver.getIdentifiers());

// Check if a recognized usb device is connected in 30 seconds
imp.wakeup(30,function(){
    local driver = usbHost.getDriver();
    if (driver != null){
    	server.log(typeof driver);
       // do something with driver here
    }
}.bindenv(this))
```

## USB.DriverBase

The USB.DriverBase class is used as the base for all drivers that use this library. It contains a set of functions that are expected by [USB.Host](#USBhost) as well as some set up functions. There are a few required functions that must be overwritten. All other functions will be documented and can be overwritten only as needed.

### Required Functions

These are the functions your usb driver class must override. The default behavior for most of these function is to throw an error.

#### getIdentifiers()

Method that returns an array of tables containing VID PID pairs. These identifiers are needed when registering a driver with the Usb.Host class, [see registerDriver()](#registerdriverdriverclassidentifiers). Once the driver is registered with USB.Host, when a device with a matching VID PID combo is connected, an instance of this driver will be passed to the callback registered to the "connected" event.

##### Example

```squirrel
class MyUsbDriver extends USB.DriverBase {

    static VID = 0x01f9;
    static PID = 0x1044;

   // Returns an array of VID PID combinations
    function getIdentifiers() {
        local identifiers = {};
        identifiers[VID] <-[PID];
        return [identifiers];
    }
}

usbHost <- USB.Host(hardware.usb);

// Register the Usb driver with usb host
usbHost.registerDriver(MyUsbDriver, MyUsbDriver.getIdentifiers());
```

#### _typeof()

The *_typeof()* method is a squirrel metamethod that returns the class name. See [metamethods documenation](https://electricimp.com/docs/resources/metamethods/)

##### Example
```squirrel
class MyUsbDriver extends USB.DriverBase {
    // Metamethod returns class name when - typeof <instance> - is called
    function _typeof() {
        return "MyUsbDriver";
    }
}

myDriver <- MyUsbDriver();

// This will log "MyUsbDriver"
server.log(typeof myDriver);
```

#### _transferComplete(*eventDetails*)

The *_transferComplete()* method is triggered when a usb transfer is completed. This example code is taken from our example Ftdi and Uart drivers.

##### Example

```squirrel
class MyUsbDriver extends USB.DriverBase {

    // Called when a Usb request is succesfully completed
    function _transferComplete(eventdetails) {

        local direction = (eventdetails["endpoint"] & 0x80) >> 7;

        if (direction == USB_DIRECTION_IN) {

            local readData = _bulkIn.done(eventdetails);
            if (readData.len() >= 3) {
                // skip first two bytes
                readData.seek(2);
                // emit data event that the user can subscribe to.
                _onEvent("data", readData.readblob(readData.len()));
            }

            // Blank the buffer
            _bulkIn.read(blob(64 + 2));

        } else if (direction == USB_DIRECTION_OUT) {
            _bulkOut.done(eventdetails);
        }
    }

}
```

### USB.DriverBase Setup Functions

This is a set of functions that are called during the set up process of the usb driver by the USB.Host. They are already implemented within the UsbDriverBase class and should not require changes.

#### Constructor: USB.DriverBase(*usbHost*)

By default the constructor takes an instance of the USB.Host class as its only parameter and assigns it to internal _usb variable accessible within the class scope. If custom initialization is required override the constructor as shown below, making sure to call the base.constructor() method. If no initialization is required let the parent class handle constructor. The USB driver is initialized by USB.Host class when a new device is connected to the USB port.

##### Example

```squirrel
class MyUsbDriver extends USB.DriverBase {

    _customOpt = null;

    constructor(usb, customOpt) {
        _customOpt = customOpt;
        base.constructor(usb);
    }

}
```

#### connect(*deviceAddress, speed, descriptors*)

This method is called by the USB.Host class after instantiation of the usb driver class. It makes calls to internal functions to set up the various endpoints (control and bulk transfer endpoints), configures the usb parameters like the baud rate and sets up the buffers.


### USB.DriverBase Class Functions

#### on(*eventName, callback*)

Subscribe a callback function to a specific event. There are no events emitted by default as connection and disconnection are handled by the USB.Host. You can emit custom events in your driver using the internal `_onEvent` function but be sure to document them.


| Key | Data Type | Required | Description |
| --- | --------- | -------- | ----------- |
| *eventName* | String | Yes | The string name of the event to subscribe to.|
| *callback* | Function | Yes | Function to be called on event |


#### off(*eventName*)

Clears a subscribed callback function from a specific event.

| Key | Data Type | Required | Description |
| --- | --------- | -------- | ----------- |
| *eventName* | String | Yes | The string name of the event to unsubscribe from.|


#### _onEvent(*eventName, eventdetails*)

This method is an internal class funciton used to emit events. The user is able to subscribe to these events using the `on` method defined in the public functions above.

| Key | Data Type | Required | Description |
| --- | --------- | -------- | ----------- |
| *eventName* | String | Yes | The string name of the event to emit to.|
| *eventdetails* | Any | Yes | If a callback is subscribed to the corresponding eventName the callback is called with eventDetails as the arguement. |


## Driver Examples

### [UartOverUsbDriver](./UartOverUsbDriver/)

The UartOverUsbDriver class creates an interface object that exposes methods similar to the uart object to provide compatability for uart drivers over usb.


### [FtdiUsbDriver](./FtdiUsbDriver/)

The FtdiUsbDriver class exposes methods to interact with a device connected to usb via an FTDI cable.


# License

This library is licensed under the [MIT License](/LICENSE).
