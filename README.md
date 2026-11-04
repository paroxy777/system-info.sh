<h1>system-info</h1>

<p>Displays basic system info.</p> 

<p>Useful for identification / inventory / sales prep / etc.</p>

<h2>Requirements</h2>
<h3>Linux</h3>
<p>Requires the package hwinfo</p>
<pre>apt install hwinfo</pre>

<h3>Windows</h3>
<p>Windows 10-11 (via CIM/WMI)</p>
<p>PowerShell Execution policy adjustment.</p>
<pre>powershell.exe -ExecutionPolicy Bypass -File .\system-info.ps1</pre>

<b>Sample Output:</b>
<pre>
LENOVO 20HGS0HK00
Intel(R) Core(TM) i7-7600U CPU @ 2.80GHz (0.4 - 3.9 GHz)
25GB RAM / 500 GB NVMe SSD / DVD
NVIDIA GeForce GTX 1050
Ubuntu 24.04.3 LTS
</pre>

<h2>To-Do</h2>
<ul>
  <ul>Improve dGPU detection for Intel Arc, AMD integrated graphics, NVIDIA Optimus and hybrid graphics configurations, etc.</ul>
  <ul>Improve NVMe detection. (Use bus type instead of model name.)</ul>
  <ul>Improve CPU speed range detection. (Use power management data).</ul>
</ul>
