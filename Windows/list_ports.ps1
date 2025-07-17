# Get the list of COM port names from the registry
$comPorts = Get-ItemProperty -Path 'HKLM:\HARDWARE\DEVICEMAP\SERIALCOMM' -ErrorAction SilentlyContinue

if ($null -eq $comPorts) {
    Write-Host "No COM ports found in the registry."
} else {
    # The properties of the object are the device names (e.g., \Device\Serial0)
    # and the values are the COM port names (e.g., COM1)
    $portData = $comPorts.PSObject.Properties | Where-Object { $_.Value -like 'COM*' } | ForEach-Object {
        [PSCustomObject]@{
            DeviceName = $_.Name
            COMPort    = $_.Value
        }
    }

    $results = foreach ($port in $portData) {
        # Find the corresponding PnP device to get more details
        $pnpDevice = Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -like "*($($port.COMPort))*" }
        
        if ($pnpDevice) {
            [PSCustomObject]@{
                COM_Port    = $port.COMPort
                Device_Name = $pnpDevice.Name
                Description = $pnpDevice.Description
                Status      = $pnpDevice.Status
                Hardware_ID = $pnpDevice.PNPDeviceID
            }
        } else {
            [PSCustomObject]@{
                COM_Port    = $port.COMPort
                Device_Name = "N/A"
                Description = "Device details not found in PnP"
                Status      = "N/A"
                Hardware_ID = "N/A"
            }
        }
    }

    # Sort by the numeric part of the COM port name
    $results | Sort-Object { [int]($_.COM_Port -replace 'COM', '') } | Format-Table -AutoSize
}
