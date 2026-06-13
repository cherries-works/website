#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>
#include <sys/types.h>

int ONE_KB = 1024;

char *SRC_DIR = "./src/pages";
char *DIST_DIR = "./dist";

char *INCLUDE_STARTER = "<#!- include(\"";
char SPACE_IN_ASCII = ' ';

void trim(char *buffer) {
    unsigned size = strlen(buffer);
    unsigned start = 0;
    while(buffer[start] == SPACE_IN_ASCII && start < size) start++;
    
    unsigned end = size;
    while(buffer[end] == SPACE_IN_ASCII && end >= 0) end--;


    // move everything to the left side
    unsigned i = 0;
    while(i < end - start) {
        buffer[i] = buffer[start + i];
        i++;
    }

    // set everything else to 0
    i = end;
    while(i < size) {
        buffer[i] = 0;
        i++;
    }

    buffer[end - start] = '\0';
}

int startsWith(char *buffer, char *starts) {
    if(strlen(buffer) < strlen(starts)) return 0;

    for(int i = 0; i < strlen(starts) - 1; i++) {
        if(buffer[i] != starts[i]) return 0;
    }

    return 1;
}

void copyDynamic(
    char *dir,
    char *dist_dir,

    char *file_buffer, 
    int file_buffer_size
) {
    mkdir(dist_dir, 0777);

    int file_name_size = ONE_KB / 4;
    char file_name[file_name_size];

    int dist_file_name_size = ONE_KB / 4;
    char dist_file_name[dist_file_name_size];

    DIR *src = opendir(dir);
    struct dirent *d_entry;
    while((d_entry = readdir(src)) != NULL) {
        sprintf(file_name, "%s/%s", dir, d_entry->d_name);
        FILE *file = fopen(file_name, "r");
        if(file == NULL) continue;

        sprintf(dist_file_name, "%s/%s", dist_dir, d_entry->d_name);

        if(d_entry->d_type == 4) {
            int len = strlen(file_name);
            if(file_name[len - 1] == '.') continue;

            copyDynamic(file_name, dist_file_name, file_buffer, file_buffer_size);
            fclose(file);
            continue;
        }

        FILE *dist_file = fopen(dist_file_name, "w");
        
        size_t n = fread(file_buffer, 1, file_buffer_size - 1, file);
        file_buffer[n] = '\0';
        
        char *line = strtok(file_buffer, "\n");
        while(line != NULL) {
            int old_len = strlen(line);
            trim(line);
            int new_len = strlen(line);
            if(new_len < old_len) {
                for(int i = 0; i < (old_len - new_len); i++) {
                    fwrite(" ", sizeof(char), 1, dist_file);
                }
            }

            if(startsWith(line, INCLUDE_STARTER) == 0) {
                fwrite(line, sizeof(char), strlen(line), dist_file);
                fwrite("\n", sizeof(char), 1, dist_file);

                line = strtok(NULL, "\n");
                continue;
            }

            line = line + strlen(INCLUDE_STARTER);

            char *string = strchr(line, '"');
            *string = '\0';


            int r_file_buffer_size = ONE_KB * 10;
            char r_file_buffer[r_file_buffer_size];
            
            FILE *read_file = fopen(line, "r"); // file_name
            size_t rn = fread(r_file_buffer, 1, r_file_buffer_size - 1, read_file);
            r_file_buffer[rn] = '\0';
            
            fwrite(r_file_buffer, 1, rn, dist_file);
            fwrite("\n", sizeof(char), 1, dist_file);

            fclose(read_file);

            line = strtok(NULL, "\n");
        }

        fclose(dist_file);
        fclose(file);
    }
}


int copyFile(char src[], char dest[]) {
    FILE *dest_stream, *src_stream;

    if ((dest_stream = fopen(dest, "wb")) == NULL) {
        fprintf(stderr, "%s: %s\n", "Impossible to create a file", dest);
        return -1;
    }

    if ((src_stream = fopen(src, "rb")) == NULL) {
        fprintf(stderr, "%s: %s\n", "Impossible to read a file", src);
        return -1;
    }

    int chr;
    while ((chr = fgetc(src_stream)) != EOF)
        fputc(chr, dest_stream);

    fclose(dest_stream);
    fclose(src_stream);

    return 0;
}


char *STYLES_SRC_DIR = "./src/styles";
char *ASSETS_SRC_DIR = "./src/assets";
char *STYLES_DIST_DIR = "./dist/styles";
char *ASSETS_DIST_DIR = "./dist/assets";
void copyStatic(
    char *dir,
    char *dist_dir
) {
    mkdir(dist_dir, 0777);

    int file_name_size = ONE_KB / 4;
    char file_name[file_name_size];

    int dist_file_name_size = ONE_KB / 4;
    char dist_file_name[dist_file_name_size];

    DIR *src = opendir(dir);
    struct dirent *d_entry;
    while((d_entry = readdir(src)) != NULL) {
        sprintf(file_name, "%s/%s", dir, d_entry->d_name);
        FILE *file = fopen(file_name, "rw");
        if(file == NULL) continue;

        sprintf(dist_file_name, "%s/%s", dist_dir, d_entry->d_name);

        if(d_entry->d_type == 4) {
            int len = strlen(file_name);
            if(file_name[len - 1] == '.') continue;

            copyStatic(file_name, dist_file_name);
            fclose(file);
            continue;
        }

        printf("%s -> %s\n", file_name, dist_file_name);
        copyFile(file_name, dist_file_name);


        fclose(file);
    }
}


int main() {
    int file_buffer_size = ONE_KB * 30;
    char file_buffer[file_buffer_size];

    copyDynamic(
        SRC_DIR, 
        DIST_DIR,
        file_buffer, 
        file_buffer_size
    );

    copyStatic(STYLES_SRC_DIR, STYLES_DIST_DIR);
    copyStatic(ASSETS_SRC_DIR, ASSETS_DIST_DIR);
}
