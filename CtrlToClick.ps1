# CtrlToClick.ps1
# While this script runs, holding Ctrl (left or right) holds down the left mouse button.
# Releasing Ctrl releases the mouse button. Ctrl's normal behavior is suppressed.
# Close this window to stop.

Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public static class CtrlToClick
{
    const int WH_KEYBOARD_LL = 13;
    const int WM_KEYDOWN = 0x0100, WM_KEYUP = 0x0101, WM_SYSKEYDOWN = 0x0104, WM_SYSKEYUP = 0x0105;
    const int VK_CONTROL = 0x11, VK_LCONTROL = 0xA2, VK_RCONTROL = 0xA3;
    const uint LLKHF_INJECTED = 0x10;
    const uint MOUSEEVENTF_LEFTDOWN = 0x0002, MOUSEEVENTF_LEFTUP = 0x0004;

    [StructLayout(LayoutKind.Sequential)]
    struct KBDLLHOOKSTRUCT { public uint vkCode, scanCode, flags, time; public IntPtr dwExtraInfo; }

    delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll", SetLastError = true)]
    static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")]
    static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr GetModuleHandle(string lpModuleName);
    [DllImport("user32.dll")]
    static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, UIntPtr dwExtraInfo);

    static LowLevelKeyboardProc proc = HookCallback; // kept in a field so it isn't garbage collected
    static IntPtr hookId = IntPtr.Zero;
    static bool mouseDown = false;

    public static void Run()
    {
        using (Process p = Process.GetCurrentProcess())
        using (ProcessModule m = p.MainModule)
        {
            hookId = SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(m.ModuleName), 0);
        }
        if (hookId == IntPtr.Zero)
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        try { Application.Run(); } // message loop required for the hook
        finally { Stop(); }
    }

    public static void Stop()
    {
        if (mouseDown) { mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero); mouseDown = false; }
        if (hookId != IntPtr.Zero) { UnhookWindowsHookEx(hookId); hookId = IntPtr.Zero; }
    }

    static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0)
        {
            KBDLLHOOKSTRUCT kb = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(KBDLLHOOKSTRUCT));
            bool isCtrl = kb.vkCode == VK_LCONTROL || kb.vkCode == VK_RCONTROL || kb.vkCode == VK_CONTROL;
            if (isCtrl && (kb.flags & LLKHF_INJECTED) == 0)
            {
                int msg = wParam.ToInt32();
                if (msg == WM_KEYDOWN || msg == WM_SYSKEYDOWN)
                {
                    // Key auto-repeat fires repeated keydowns; only press the button once.
                    if (!mouseDown) { mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero); mouseDown = true; }
                }
                else if (msg == WM_KEYUP || msg == WM_SYSKEYUP)
                {
                    if (mouseDown) { mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero); mouseDown = false; }
                }
                return (IntPtr)1; // swallow the Ctrl key so it doesn't act as Ctrl
            }
        }
        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
}
"@

Write-Host "Ctrl -> Left Mouse is ACTIVE. Hold Ctrl to hold left click."
Write-Host "Close this window to stop."
try { [CtrlToClick]::Run() } finally { [CtrlToClick]::Stop() }
