# Windows roadmap

**Status: proposed port. No Windows application or installer is included.**

The same interaction is feasible on Windows: a small system-tray companion hears “Hey” plus the configured word, releases its microphone, and sends the desktop voice shortcut. The current application uses AppKit, Apple Speech, CoreAudio, and macOS Accessibility, so it cannot simply be packaged as an `.exe`.

## Keep the experience

- A tray icon and compact settings popup, with no main window or extra ready sound.
- A customizable word after “Hey”, local recognition, and no API key requirement.
- A matching voice shortcut with capture isolated only while recording it.
- Pause, startup preference, clear permission/device errors, and automatic re-arming after a call.
- Other apps' audio must not create an unexplained permanent block.

## Work required

1. Verify the installed Windows desktop app exposes and responds to a global **Voice chat hotkey**. OpenAI documents this setting, but this repository has not tested its Windows behavior, permissions, or availability.
2. Implement a native tray host. A .NET companion using Windows `NotifyIcon` is one option; UI framework selection remains open.
3. Select and benchmark an offline speech/wake engine that supports user-selected words. Check redistribution rights, language/accent coverage, model size, CPU use, and false activations before committing to a dependency.
4. Implement shortcut recording and dispatch using supported Windows APIs. Test normal/elevated-app boundaries; do not require users to run everything as administrator.
5. Implement and verify microphone handoff and call-state detection. Do not assume macOS's per-process audio checks have a drop-in Windows equivalent.
6. Port the behavior tests for startup protection, short-call re-arming, suspended sessions, repeated results, and unrelated audio activity.
7. Test on Windows 11 with actual microphones and the desktop voice app, then package and sign an installer.

Apple custom language models and macOS permissions do not transfer to Windows. No reliable Windows accuracy, call detection, or launch compatibility is claimed until measured.

## References

- [OpenAI: Voice setup and hotkey](https://learn.chatgpt.com/docs/features/voice)
- [Microsoft: notification-area icons](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.notifyicon)
- [Microsoft: keyboard input dispatch and integrity-level constraints](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendinput)
