import Foundation

// Prints the SMC temperature keys the app reads for a chip name, one
// "<group> <key>" pair per line, using the app's own sensor catalog.
let chipName = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ""
let sensors = SMCTemperatureSensorCatalog.sensors(chipName: chipName, isAppleSilicon: true)

for key in sensors.cpuKeys { print("cpu \(key)") }
for key in sensors.gpuKeys { print("gpu \(key)") }
for sensor in sensors.storageSensors { print("storage \(sensor.key)") }
