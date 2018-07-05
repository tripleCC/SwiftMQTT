# SwiftMQTT
[详情博客](http://triplecc.github.io/blog/2016-05-12-mqttshi-yong-xiao-ji/)

MQTT协议中文版：[https://mcxiaoke.gitbooks.io/mqtt-cn/content/](https://mcxiaoke.gitbooks.io/mqtt-cn/content/) <br>
MQTT协议英文版：[http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html)

## 如何使用

- 创建MQTT Client与MQTT Account

```
client = SwiftMQTTClient(clientId: NSProcessInfo().globallyUniqueString, account: SwiftMQTTAccount(username: "tripleCC", password: "cg"), keepalive: 90)
```

- 设置连接地址与端口

```
client?.connectToHost("localhost", port: 1883)
```

- 设置代理并实现相关代理协议，监听收到的信息

```
self.client?.delegate = self

// SwiftMQTTClientDelegate
func mqttClient(client: SwiftMQTTClient, didReceiveMessage message: SwiftMQTTAckMessageProtocol?)
```

- 基本操作

```
// 订阅主题
client?.subscribeMessageWithTopics(["ziroomer/+"], qosLevels: [.AtLeastOnce])

// 取消订阅主题
client?.unsubscribeMessageWithTopics(["ziroomer/+"])

// 发送信息
client?.publishMessageWithTopicName("ziroomer/wifi", message: "tripleCC", qosLevel: .ExactlyOnce)

// 断开连接
client?.disconnect()
```
