#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <syslog.h>
#include <signal.h>
#include <fcntl.h>

#define PORT 9000
#define BACKLOG 10
#define FILE_PATH "/var/tmp/aesdsocketdata"
#define BUFFER_SIZE 1024

volatile sig_atomic_t exit_flag = 0;

void signal_handler(int signo) {
    syslog(LOG_INFO, "Caught signal, exiting");
    exit_flag = 1;
}

void clean_exit(int sockfd, int filefd) {
    if (sockfd >= 0) close(sockfd);
    if (filefd >= 0) close(filefd);
    unlink(FILE_PATH);
    closelog();
}

void daemonize() {
    pid_t pid = fork();
    if (pid < 0) {
        perror("fork");
        exit(EXIT_FAILURE);
    }
    if (pid > 0) exit(EXIT_SUCCESS);

    if (setsid() < 0) {
        perror("setsid");
        exit(EXIT_FAILURE);
    }

    if (chdir("/") < 0) {
        perror("chdir");
        exit(EXIT_FAILURE);
    }

    close(STDIN_FILENO);
    close(STDOUT_FILENO);
    close(STDERR_FILENO);
}

int main(int argc, char *argv[]) {
    int sockfd = -1, clientfd = -1, filefd = -1;
    struct sockaddr_in serv_addr, client_addr;
    socklen_t addr_len = sizeof(client_addr);

    char temp_buffer[BUFFER_SIZE];
    char *recv_buffer = NULL;
    ssize_t bytes_received;
    int daemon_mode = 0;
    int total_received = 0;

    if (argc == 2 && strcmp(argv[1], "-d") == 0) {
        daemon_mode = 1;
    }

    openlog("aesdsocket", LOG_PID, LOG_USER);

    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = signal_handler;
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);

    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) {
        syslog(LOG_ERR, "Socket creation failed: %s", strerror(errno));
        exit(EXIT_FAILURE);
    }

    // Allow socket address reuse
    int optval = 1;
    setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof(optval));

    memset(&serv_addr, 0, sizeof(serv_addr));
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    serv_addr.sin_port = htons(PORT);

    if (bind(sockfd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0) {
        syslog(LOG_ERR, "Bind failed: %s", strerror(errno));
        clean_exit(sockfd, -1);
        exit(EXIT_FAILURE);
    }

    if (listen(sockfd, BACKLOG) < 0) {
        syslog(LOG_ERR, "Listen failed: %s", strerror(errno));
        clean_exit(sockfd, -1);
        exit(EXIT_FAILURE);
    }

    if (daemon_mode) {
        daemonize();
    }

    while (!exit_flag) {
        clientfd = accept(sockfd, (struct sockaddr *)&client_addr, &addr_len);

        if (clientfd < 0) {
            if (errno == EINTR) break;
            syslog(LOG_ERR, "Accept failed: %s", strerror(errno));
            continue;
        }

        char client_ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &client_addr.sin_addr, client_ip, INET_ADDRSTRLEN);
        syslog(LOG_INFO, "Accepted connection from %s", client_ip);

        filefd = open(FILE_PATH, O_RDWR | O_CREAT | O_APPEND, 0644);

        if (filefd < 0) {
            syslog(LOG_ERR, "File open failed: %s", strerror(errno));
            close(clientfd);
            continue;
        }

        // Initialize variables for receiving data
        total_received = 0;
        recv_buffer = NULL;

        // Receive data until a newline character is found
        do {
            bytes_received = recv(clientfd, temp_buffer, BUFFER_SIZE, 0);
            if (bytes_received < 0) {
                syslog(LOG_ERR, "Receive failed: %s", strerror(errno));
                break;
            } else if (bytes_received == 0) {
                // Connection closed by client
                break;
            } else {
                // Allocate or expand recv_buffer
                char *new_recv_buffer = realloc(recv_buffer, total_received + bytes_received);
                if (new_recv_buffer == NULL) {
                    syslog(LOG_ERR, "Memory allocation failed");
                    free(recv_buffer);
                    recv_buffer = NULL;
                    break;
                }
                recv_buffer = new_recv_buffer;

                // Copy received data to recv_buffer
                memcpy(recv_buffer + total_received, temp_buffer, bytes_received);
                total_received += bytes_received;

                // Check if a newline is in the received data
                if (memchr(temp_buffer, '\n', bytes_received) != NULL) {
                    break;
                }
            }
        } while (1);

        // Write the accumulated data to the file
        if (recv_buffer != NULL && total_received > 0) {
            if (write(filefd, recv_buffer, total_received) != total_received) {
                syslog(LOG_ERR, "Write to file failed: %s", strerror(errno));
            }
        }

        // Send the contents of the file back to the client
        lseek(filefd, 0, SEEK_SET); // Reset file pointer to start
        while ((bytes_received = read(filefd, temp_buffer, BUFFER_SIZE)) > 0) {
            if (send(clientfd, temp_buffer, bytes_received, 0) != bytes_received) {
                syslog(LOG_ERR, "Send to client failed: %s", strerror(errno));
                break;
            }
        }
        if (bytes_received < 0) {
            syslog(LOG_ERR, "Read from file failed: %s", strerror(errno));
        }

        // Clean up for this client
        free(recv_buffer);
        recv_buffer = NULL;

        close(clientfd);
        clientfd = -1;

        syslog(LOG_INFO, "Closed connection from %s", client_ip);

        close(filefd);
        filefd = -1;
    }

    clean_exit(sockfd, filefd);
    return 0;
}

