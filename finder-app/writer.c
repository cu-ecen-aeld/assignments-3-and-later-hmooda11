#include <stdio.h>
#include <stdlib.h>
#include <syslog.h>
#include <string.h>

int main(int argc, char *argv[]) {
	if(argc !=3) {
		syslog(LOG_ERR, "Invalid number of arguments: expected 2, got %d", argc - 1);
		fprintf(stderr, "Usage: %s <file> <string>\n", argv[0]);
		return 1;
	}
	const char *file_path = argv[1];
	const char *string = argv[2];

	openlog("writer", LOG_PID, LOG_USER);
	
	FILE *file = fopen(file_path, "w");
	if (file == NULL) {
		syslog(LOG_ERR, "Error opening the file %s", file_path);
		perror("Error opening file");
		closelog();
		return 1;
	}
	
	fprintf(file, "%s", string);
	fclose(file);
        syslog(LOG_DEBUG, "Writing %s to %s", string, file_path);

	closelog();
	return 0;

}
