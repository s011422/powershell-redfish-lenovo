﻿###
#
# Lenovo Redfish examples - Get the network information
#
# Copyright Notice:
#
# Copyright 2018 Lenovo Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
###


###
#  Import utility libraries
###
Import-module $PSScriptRoot\lenovo_utils.psm1

function get_pci_inventory
{
    <#
   .Synopsis
    Cmdlet used to get pci inventory
   .DESCRIPTION
    Cmdlet used to get pci inventory from BMC using Redfish API. Connection information can be specified via command parameter or configuration file.
    - ip: Pass in BMC IP address
    - username: Pass in BMC username
    - password: Pass in BMC username password
    - system_id:Pass in ComputerSystem instance id(None: first instance, all: all instances)
    - config_file: Pass in configuration file path, default configuration file is config.ini
   .EXAMPLE
    get_pci_inventory -ip 10.10.10.10 -username USERID -password PASSW0RD
   #>
   
    param(
        [Parameter(Mandatory=$False)]
        [string]$ip="",
        [Parameter(Mandatory=$False)]
        [string]$username="",
        [Parameter(Mandatory=$False)]
        [string]$password="",
        [Parameter(Mandatory=$False)]
        [string]$system_id="None",
        [Parameter(Mandatory=$False)]
        [string]$config_file="config.ini"
        )
        

    # Get configuration info from config file
    $ht_config_ini_info = read_config -config_file $config_file
    
    # If the parameter is not specified via command line, use the setting from configuration file
    if ($ip -eq "")
    { 
        $ip = [string]($ht_config_ini_info['BmcIp'])
    }
    if ($username -eq "")
    {
        $username = [string]($ht_config_ini_info['BmcUsername'])
    }
    if ($password -eq "")
    {
        $password = [string]($ht_config_ini_info['BmcUserpassword'])
    }
    if ($system_id -eq "")
    {
        $system_id = [string]($ht_config_ini_info['SystemId'])
    }

    try
    {
        $session_key = ""
        $session_location = ""

        # Create session
        $session = create_session -ip $ip -username $username -password $password
        $session_key = $session.'X-Auth-Token'
        $session_location = $session.Location

        # Build headers with sesison key for authentication
        $JsonHeader = @{ "X-Auth-Token" = $session_key
        }
        
        # Get the chassis url
        $base_url = "https://$ip/redfish/v1/"
        $response = Invoke-WebRequest -Uri $base_url -Headers $JsonHeader -Method Get -UseBasicParsing
        $converted_object = $response.Content | ConvertFrom-Json
        $chassis_url = $converted_object.Chassis."@odata.id"

        #Get chassis list 
        $chassis_url_collection = @()
        $chassis_url_string = "https://$ip"+ $chassis_url
        $response = Invoke-WebRequest -Uri $chassis_url_string -Headers $JsonHeader -Method Get -UseBasicParsing
        $converted_object = $response.Content | ConvertFrom-Json
        foreach($i in $converted_object.Members)
        {
               $tmp_chassis_url_string = "https://$ip" + $i."@odata.id"
               $chassis_url_collection += $tmp_chassis_url_string
        }

        # Loop all System resource instance in $chassis_url_collection
        foreach($chassis_url_string in $chassis_url_collection)
        {
            # Get system resource
            $response = Invoke-WebRequest -Uri $chassis_url_string -Headers $JsonHeader -Method Get -UseBasicParsing
            $converted_object = $response.Content | ConvertFrom-Json

            # Get PCIeDevices resource 
            $pci_devices_url = "https://$ip" + $converted_object.PCIeDevices."@odata.id"
            $response = Invoke-WebRequest -Uri $pci_devices_url -Headers $JsonHeader -Method Get -UseBasicParsing
            $converted_pci_object = $response.Content | ConvertFrom-Json

            # Get pci count
            $pci_x_count =$converted_pci_object."Members@odata.count"

            # Loop all pci resource instance in EthernetInterfaces resource
            for($i = 0;$i -lt $pci_x_count;$i ++)
            {
                $ht_pcidevice = @{}

                # Get pci resource
                $pci_device_x_url ="https://$ip" +  $converted_pci_object.Members[$i]."@odata.id"
                $response_pci_x_device = Invoke-WebRequest -Uri $pci_device_x_url -Headers $JsonHeader -Method Get -UseBasicParsing
                $converted_pci_x_object = $response_pci_x_device.Content | ConvertFrom-Json
                $ht_pcidevice["PCI_Device_ID"] = $converted_pci_x_object.Id
                $ht_pcidevice["Name"] = $converted_pci_x_object.Name
                $ht_pcidevice["Status"] = $converted_pci_x_object.Status
                $ht_pcidevice["Manufacturer"] = $converted_pci_x_object.Manufacturer
                $ht_pcidevice["Model"] = $converted_pci_x_object.Model
                $ht_pcidevice["DeviceType"] = $converted_pci_x_object.DeviceType
                $ht_pcidevice["SerialNumber"] = $converted_pci_x_object.SerialNumber
                $ht_pcidevice["PartNumber"] = $converted_pci_x_object.PartNumber
                $ht_pcidevice["FirmwareVersion"] = $converted_pci_x_object.FirmwareVersion
                $ht_pcidevice["SKU"] = $converted_pci_x_object.SKU

                # Retrun result
                $ht_pcidevice
                Write-Host " "
            }
        }  
    }
    catch
    {
        # Handle exception response
        $ret = handle_exception -arg_object $_
        $ret
        return $False
    }
    # Delete existing session whether script exit successfully or not
    finally
    {
        if ($session_key -ne "")
        {
            delete_session -ip $ip -session $session
        }
    }
}
