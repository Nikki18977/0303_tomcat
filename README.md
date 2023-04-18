# Week 03. Apache Tomcat Task (Slurm Навыкум "Build Containers!")

## Задача

Есть проект, использующий [Servlet API](https://jakarta.ee/specifications/servlet/6.0/) из [Jakarta EE](https://jakarta.ee/specifications/)

Проект рассчитан на запуск в [Apache Tomcat](https://tomcat.apache.org/tomcat-10.1-doc/index.html) версии 10.1.x

### Безопасность

В этом проекте всё максимально серьёзно: мы никому не доверяем, поэтому сами собрали ключевые компоненты:
1. [Root ФС*](https://github.com/slurmorg/build-containers-trusted/blob/main/rootfs.tar.gz) (вместе с установленной Java)
2. [Maven](https://github.com/slurmorg/build-containers-trusted/blob/main/apache-maven-3.9.1-bin.tar.gz)
3. [Tomcat](https://github.com/slurmorg/build-containers-trusted/blob/main/apache-tomcat-10.1.7.tar.gz)

Для всех файлов сосчитаны контрольные суммы (файлы с расширением `*.sha512`) и все файлы с контрольными суммами подписаны (файлы с расширением `*.sha512.asc`)

Публичный ключ, с помощью которого можно проверить подпись, расположен в репозитории под именем [`key.gpg`](https://github.com/slurmorg/build-containers-trusted/blob/main/key.gpg)

Отпечаток ключа: `70092656FB28DBB76C3BB42E89619023B6601234`

Посмотреть можно командой:
```shell
gpg --dry-run --import --import-options import-show ./key.gpg 
pub   rsa4096 2023-04-09 [SCEA] [expires: 2033-04-06]
      70092656FB28DBB76C3BB42E89619023B6601234
uid                      Slurm (Main Key) <slurm@slurm.io>

gpg: Total number processed: 1
```

### Сборка

#### Этап 1 (верификация)

Для верификации файлов берём доверенный образ от [Bellsoft](https://hub.docker.com/layers/bellsoft/alpaquita-linux-gcc/12.2-glibc/images/sha256-de48a2ba305651797f83180718a620e525f97a4155900b533752ca0fe557d476)

**Важно**: URL'ы файлов должны быть заданы с помощью аргументов сборки:
1. `GPG_KEY_URL`
2. `ROOTFS_URL`
3. `MAVEN_URL`
4. `TOMCAT_URL`

URL'ы файлов с контрольными суммами и подписями (для п.1-4) рассчитываются путём добавления соответствующих суффиксов

Затем устанавливаем туда [`GnuPG`](https://gnupg.org/) и проверяем все файлы в следующем порядке:
1. Сначала проверяем отпечаток ключа `key.gpg` (должен быть `70092656FB28DBB76C3BB42E89619023B6601234`)
2. Затем проверяем контрольные суммы файлов с расширением `tar.gz`
3. Затем проверяем подписи файлов с контрольными суммами

Если всё ОК, то переходим к этапу 2

#### Этап 2 (сборка)

Берём `Scratch`, накатываем туда:
1. Root ФС
2. Maven (в каталог `/opt/bin/maven`)

**Важно**: Maven должен быть именно в `/opt/bin/maven`, а не в `/opt/bin/maven/apache-maven-3.9.1`

Прописываем следующие переменные окружения:
1. `PATH=/usr/lib/jvm/jdk-17.0.6-bellsoft-x86_64/bin:/opt/bin/maven/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`
2. `LANG=en_US.UTF-8`
3. `LANGUAGE=en_US.UTF-8:en`
4. `JAVA_HOME=/usr/lib/jvm/jdk-17.0.6-bellsoft-x86_64`
5. `MAVEN_HOME=/opt/bin/maven`

Запускаем сборку:
```shell
mvn verify
```

В результате должен появиться файл `target/api.war`

#### Этап 3 (публикация)

Берём `Scratch`, накатываем туда:
1. Root ФС
2. Tomcat (в каталог `/opt/bin/tomcat`)

**Важно**: Maven должен быть именно в `/opt/bin/tomcat`, а не в `/opt/bin/tomcat/apache-tomcat-10.1.7`

Прописываем следующие переменные окружения:
1. `PATH=/usr/lib/jvm/jdk-17.0.6-bellsoft-x86_64/bin:/opt/bin/tomcat/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`
2. `LANG=en_US.UTF-8`
3. `LANGUAGE=en_US.UTF-8:en`
4. `JAVA_HOME=/usr/lib/jvm/jdk-17.0.6-bellsoft-x86_64`
5. `CATALINA_HOME=/opt/bin/tomcat`

В качестве `CMD` указать `catalina.sh run`

WAR закинуть в `$CATALINA_HOME/webapps` так, чтобы приложение было доступно по адресу: `http://localhost:8080/api` (тестировать методом `GET`) в ответ придёт:
```json
{"status": "ok"}
```

Стандартные приложения (вроде `manager` и остальных) [нужно удалить](https://github.com/docker-library/tomcat/pull/181)


### Что нужно сделать

1. Собрать всё согласно описанию выше (по этапам)
2. Выложить результаты последнего этапа в виде публичного образа на GHCR (GitHub Container Registry)

