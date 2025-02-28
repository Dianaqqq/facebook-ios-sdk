// Copyright (c) 2014-present, Facebook, Inc. All rights reserved.
//
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Facebook.
//
// As with any software that integrates with the Facebook platform, your use of
// this software is subject to the Facebook Developer Principles and Policies
// [http://developers.facebook.com/policy/]. This copyright notice shall be
// included in all copies or substantial portions of the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import TestTools

enum SampleContextDialogs {

  static func showCreateContextDialog(withDelegate delegate: ContextDialogDelegate) -> CreateContextDialog? {
    let content = CreateContextContent(playerID: "1234567890")
    let dialog = CreateContextDialog(
      content: content,
      windowFinder: TestWindowFinder(),
      delegate: delegate
    )
    dialog.show()
    return dialog
  }

  static func showChooseContextDialogWithInvalidSizes(delegate: ContextDialogDelegate) -> ChooseContextDialog? {
    Settings.appID = "abc123"
    let content = ChooseContextContent()
    content.minParticipants = 2
    content.maxParticipants = 1
    let dialog = ChooseContextDialog(content: content, delegate: delegate)

    return dialog
  }

  static func chooseContextDialogWithoutContentValues(delegate: ContextDialogDelegate) -> ChooseContextDialog? {
    let content = ChooseContextContent()
    let dialog = ChooseContextDialog(content: content, delegate: delegate)

    return dialog
  }

  static func chooseContextDialog(
    utility: InternalUtilityProtocol,
    delegate: ContextDialogDelegate
  ) -> ChooseContextDialog? {
    let content = ChooseContextContent()
    let dialog = ChooseContextDialog(content: content, delegate: delegate, internalUtility: utility)

    return dialog
  }
}
