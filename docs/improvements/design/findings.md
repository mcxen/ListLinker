**1. 避免系统导航栏遮挡列表底部**

列表末项需要根据设备安全区域动态增加底部留白。

**Link:** https://flutterpro.design/details/md/safe-area-replacement

**2. 让横向列表看起来可以滚动**

在横向内容边缘加入渐隐提示，避免用户不知道还有更多内容。

**Link:** https://flutterpro.design/details/md/shader-mask

**3. 平滑加载网络图片**

加载期间显示占位，完成后淡入，失败时显示友好的错误状态。

**Link:** https://flutterpro.design/details/md/smooth-image-loading

**4. 预加载图片和图标**

启动阶段预加载常用资源，避免首次显示时晚几帧出现。

**Link:** https://flutterpro.design/details/md/precache-icons

**5. 提示用户列表项支持滑动操作**

首次进入相关页面时，自动短暂展示滑动操作。

**Link:** https://flutterpro.design/details/md/flutter-slidable-controller

**6. 按用户地区格式化数字**

计数、金额和较大数字不应直接显示原始数值。

**Link:** https://flutterpro.design/details/md/format-numbers-for-humans

**7. Flutter Web 启动时显示加载状态**

避免网页加载期间只显示空白页面。

**Link:** https://flutterpro.design/details/md/flutter-web-loading-progress

**8. 为关键操作补充触觉反馈**

切换、提交成功、错误和开关操作应提供轻微振动反馈。

**Link:** https://flutterpro.design/details/md/haptic-feedback

**9. 为动态数字使用等宽数字**

计时器、进度和计数变化时不应左右跳动。

**Link:** https://flutterpro.design/details/md/tabular-figures

**10. 为 Web 链接提供分享预览卡片**

补齐标题、描述、预览图和社交平台元信息。

**Link:** https://flutterpro.design/details/md/flutter-web-og-image

**11. 滚动表单时收起键盘**

用户开始滚动后，键盘不应继续遮挡内容。

**Link:** https://flutterpro.design/details/md/dismiss-keyboard-on-scroll

**12. Web 和桌面端不要使用移动端页面转场**

桌面端页面切换应直接、克制，不使用手机式滑入动画。

**Link:** https://flutterpro.design/details/md/web-page-transitions

**13. 扩大可点击区域**

包含留白的整行或整块区域都应响应点击。

**Link:** https://flutterpro.design/details/md/gesture-detector-hit-area

**14. 按用户地区格式化日期**

避免直接显示原始时间字符串或手工拼接日期。

**Link:** https://flutterpro.design/details/md/format-date-times

**15. 无标题栏页面滚动时渐隐顶部内容**

避免滚动内容与状态栏中的时间、电量等信息碰撞。

**Link:** https://flutterpro.design/details/md/progressive-fade

**16. 根据当前页面更新浏览器标签标题**

不同页面应在浏览器标签、历史记录和书签中显示对应名称。

**Link:** https://flutterpro.design/details/md/browser-tab-title

**17. 打开弹窗前取消输入框焦点**

避免弹窗关闭后键盘意外重新出现。

**Link:** https://flutterpro.design/details/md/unfocus-before-modal

**18. 为输入框设置正确的键盘操作**

多字段表单应支持“下一项”，最后一项应能直接完成或提交。

**Link:** https://flutterpro.design/details/md/text-input-action

**19. 让底部弹层平滑且可拖动**

小型底部弹层需要更自然的拖拽和关闭体验。

**Link:** https://flutterpro.design/details/md/smooth-draggable-bottom-sheets

**20. 为全屏弹层使用现代样式**

全屏弹层应支持从顶部下拉关闭，并使用更自然的过渡效果。

**Link:** https://flutterpro.design/details/md/adaptive-sheet-route
