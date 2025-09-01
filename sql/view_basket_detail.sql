-- 장바구니 상세조회 view
CREATE OR REPLACE VIEW v_basket_detail AS
SELECT
  b.basket_code,
  b.stu_code,
  v.*              -- v_lecture_search에 담긴 강의/과목/교수/시간표 등
FROM basket b
JOIN v_lecture_search v ON v.lecture_code = b.lecture_code;

-- 장바구니 담기
-- DELIMITER 가 적용되지 않아 한줄 프로시저로 작성 

USE fairclass;

DROP PROCEDURE IF EXISTS fairclass.sp_basket_add;

CREATE PROCEDURE fairclass.sp_basket_add(IN p_stu_code BIGINT, IN p_lecture_code BIGINT)
INSERT INTO fairclass.basket (lecture_code, stu_code)
SELECT p_lecture_code, p_stu_code
FROM fairclass.lecture l
JOIN fairclass.subject s ON s.subject_code = l.subject_code
WHERE l.lecture_code = p_lecture_code
  AND l.cancel = 'N'
  AND NOT EXISTS (SELECT 1 FROM fairclass.basket        WHERE stu_code = p_stu_code AND lecture_code = p_lecture_code)
  AND NOT EXISTS (SELECT 1 FROM fairclass.applicant     WHERE stu_code = p_stu_code AND lecture_code = p_lecture_code)
  AND NOT EXISTS (SELECT 1 FROM fairclass.class_history WHERE stu_code = p_stu_code AND lecture_code = p_lecture_code)
  AND (
        (SELECT COALESCE(SUM(s2.grade),0)
         FROM fairclass.basket b
         JOIN fairclass.lecture l2 ON l2.lecture_code = b.lecture_code
         JOIN fairclass.subject s2 ON s2.subject_code = l2.subject_code
         WHERE b.stu_code = p_stu_code
           AND l2.semester_code = l.semester_code
        ) + s.grade
      ) <= 18
  AND NOT EXISTS (
        SELECT 1
        FROM fairclass.lecture_time t_new
        WHERE t_new.lecture_code = l.lecture_code
          AND EXISTS (
            SELECT 1
            FROM fairclass.basket b
            JOIN fairclass.lecture      l_old ON l_old.lecture_code = b.lecture_code
            JOIN fairclass.lecture_time t_old ON t_old.lecture_code = l_old.lecture_code
            WHERE b.stu_code = p_stu_code
              AND l_old.semester_code = l.semester_code
              AND t_old.day_of_week   = t_new.day_of_week
              AND t_old.start_time    < t_new.end_time
              AND t_new.start_time    < t_old.end_time
          )
      );

-- 테스트 : CALL fairclass.sp_basket_add(1, 5);
-- SELECT * FROM fairclass.basket WHERE stu_code=1 ORDER BY basket_code;


-- 장바구니 삭제 

DROP PROCEDURE IF EXISTS fairclass.sp_basket_remove;
CREATE PROCEDURE fairclass.sp_basket_remove(IN p_stu BIGINT, IN p_lec BIGINT)
DELETE FROM fairclass.basket
WHERE stu_code = p_stu AND lecture_code = p_lec
LIMIT 1
RETURNING basket_code AS removed_basket_code, lecture_code, stu_code;
-- 테스트 : CALL fairclass.sp_basket_remove(1, 5);
