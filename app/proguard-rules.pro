# Compose / Material3 都自带 consumer rules，这里只需要保住反射用到的入口。

# 序列化用的是手写的 org.json，没有反射，不用额外规则。

# 保留行号，崩溃栈才好看
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
