CREATE TABLE user (
    user_id INT NOT NULL,
    first_name VARCHAR(255) NOT NULL,
    PRIMARY KEY (user_id)
);
CREATE TABLE post (
    post_id INT NOT NULL AUTO_INCREMENT,
    content VARCHAR(255) NOT NULL,
    author_user_id INT NOT NULL,
    PRIMARY KEY (post_id),
    FOREIGN KEY (author_user_id) REFERENCES user(user_id)
);
