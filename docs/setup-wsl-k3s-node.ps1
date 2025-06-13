# PowerShell script to set up WSL2 K3s node with bridged networking
# Run this from Windows PowerShell as Administrator

Write-Host "Setting up WSL2 K3s Node with Bridged Networking" -ForegroundColor Green

# Step 1: Create Hyper-V External Switch
Write-Host "`nStep 1: Creating Hyper-V External Switch..." -ForegroundColor Yellow
$adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up" -and $_.Name -like "Ethernet*"} | Select-Object -First 1
if ($adapter) {
    Write-Host "Using network adapter: $($adapter.Name)"
    New-VMSwitch -Name "WSLBridge" -NetAdapterName $adapter.Name -AllowManagementOS $true -ErrorAction SilentlyContinue
    if ($?) {
        Write-Host "Virtual switch created successfully" -ForegroundColor Green
    } else {
        Write-Host "Virtual switch may already exist or creation failed" -ForegroundColor Yellow
    }
} else {
    Write-Host "No suitable network adapter found. Please create the switch manually." -ForegroundColor Red
}

# Step 2: Create .wslconfig
Write-Host "`nStep 2: Creating .wslconfig for bridged networking..." -ForegroundColor Yellow
$wslconfig = @"
[wsl2]
memory=32GB
processors=8
networkingMode=bridged
vmSwitch=WSLBridge

[experimental]
hostAddressLoopback=true
"@
$wslconfig | Out-File -FilePath "$env:USERPROFILE\.wslconfig" -Encoding UTF8
Write-Host ".wslconfig created at $env:USERPROFILE\.wslconfig" -ForegroundColor Green

# Step 3: Shut down WSL
Write-Host "`nStep 3: Shutting down WSL..." -ForegroundColor Yellow
wsl --shutdown
Start-Sleep -Seconds 5

# Step 4: Install new WSL instance
Write-Host "`nStep 4: Installing Ubuntu 22.04 as k3s-gpu-node..." -ForegroundColor Yellow
wsl --install -d Ubuntu-22.04 --no-launch
wsl --import k3s-gpu-node "$env:LOCALAPPDATA\WSL\k3s-gpu-node" "$env:TEMP\ubuntu-22.04.tar" --version 2
Write-Host "WSL instance 'k3s-gpu-node' created" -ForegroundColor Green

# Step 5: Create firewall rules
Write-Host "`nStep 5: Creating Windows Firewall rules..." -ForegroundColor Yellow
$rules = @(
    @{DisplayName="K3s API"; Protocol="TCP"; LocalPort=6443},
    @{DisplayName="SSH WSL"; Protocol="TCP"; LocalPort=22},
    @{DisplayName="BGP"; Protocol="TCP"; LocalPort=179},
    @{DisplayName="Kubelet"; Protocol="TCP"; LocalPort=10250},
    @{DisplayName="Cilium Health"; Protocol="TCP"; LocalPort=4240},
    @{DisplayName="Cilium VXLAN"; Protocol="UDP"; LocalPort=8472}
)

foreach ($rule in $rules) {
    New-NetFirewallRule -DisplayName $rule.DisplayName -Direction Inbound -Protocol $rule.Protocol -LocalPort $rule.LocalPort -Action Allow -ErrorAction SilentlyContinue
    Write-Host "Created firewall rule: $($rule.DisplayName)" -ForegroundColor Green
}

Write-Host "`nSetup complete! Next steps:" -ForegroundColor Green
Write-Host "1. Start the new instance: wsl -d k3s-gpu-node" -ForegroundColor White
Write-Host "2. Configure static IP in /etc/netplan/" -ForegroundColor White
Write-Host "3. Install NVIDIA container toolkit" -ForegroundColor White
Write-Host "4. Join the K3s cluster" -ForegroundColor White