#!/bin/bash

java -Xss64m -cp commutativity-plugin-test/target/scala-2.12/commutativity-plugin-test-assembly-1.1-SNAPSHOT.jar viper.silicon.SiliconRunner --plugin commutativity.CommutativityPlugin --disableCatchingExceptions --checkTimeout=30 "$@"
