#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

// MethodChannel for simulate-paste
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  // Set up simulate-paste channel
  paste_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "localsend/paste",
      &flutter::StandardMethodCodec::GetInstance());
  paste_channel_->SetMethodCallHandler(
      [](const auto& call, auto result) {
        if (call.method_name() == "simulatePaste") {
          // Ctrl+V via SendInput (stable Windows API since Win2K)
          INPUT inputs[4] = {};
          inputs[0].type = INPUT_KEYBOARD;
          inputs[0].ki.wVk = VK_CONTROL;
          inputs[1].type = INPUT_KEYBOARD;
          inputs[1].ki.wVk = 0x56; // 'V'
          inputs[2].type = INPUT_KEYBOARD;
          inputs[2].ki.wVk = 0x56;
          inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;
          inputs[3].type = INPUT_KEYBOARD;
          inputs[3].ki.wVk = VK_CONTROL;
          inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;
          ::SendInput(4, inputs, sizeof(INPUT));
          result->Success(flutter::EncodableValue(true));
        } else {
          result->NotImplemented();
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
