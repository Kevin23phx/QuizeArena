import { randomInt } from 'node:crypto';
import { AppError } from '../../core/errors/app-error.js';
import type { CreateCourseInput, JoinCourseInput, ListCoursesQuery } from './course.schemas.js';
import { CourseMembershipModel } from './course-membership.model.js';
import { CourseModel } from './course.model.js';
import type { UserRole } from '../auth/user.model.js';

const JOIN_CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const JOIN_CODE_LENGTH = 8;
const MAX_CODE_GENERATION_ATTEMPTS = 5;

function generateJoinCode(): string {
  return Array.from({ length: JOIN_CODE_LENGTH }, () => {
    return JOIN_CODE_ALPHABET[randomInt(0, JOIN_CODE_ALPHABET.length)];
  }).join('');
}

function isDuplicateKeyError(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    error.code === 11000
  );
}

export async function createCourse(input: CreateCourseInput, teacherId: string) {
  for (let attempt = 1; attempt <= MAX_CODE_GENERATION_ATTEMPTS; attempt += 1) {
    try {
      const course = await CourseModel.create({
        ...input,
        teacherId,
        joinCode: generateJoinCode(),
      });

      return {
        id: course.id,
        name: course.name,
        description: course.description,
        teacherId: course.teacherId.toString(),
        joinCode: course.joinCode,
        createdAt: course.createdAt,
      };
    } catch (error: unknown) {
      if (!isDuplicateKeyError(error)) {
        throw error;
      }
    }
  }

  throw new AppError(500, 'JOIN_CODE_GENERATION_FAILED', 'Could not generate a unique course join code.');
}

export async function joinCourse(input: JoinCourseInput, studentId: string) {
  const course = await CourseModel.findOne({ joinCode: input.joinCode }).select('_id');

  if (!course) {
    throw new AppError(404, 'COURSE_NOT_FOUND', 'No course matches this join code.');
  }

  try {
    const membership = await CourseMembershipModel.create({
      courseId: course._id,
      studentId,
    });

    return {
      created: true,
      membership: {
        courseId: membership.courseId.toString(),
        studentId: membership.studentId.toString(),
        joinedAt: membership.joinedAt,
      },
    };
  } catch (error: unknown) {
    if (!isDuplicateKeyError(error)) {
      throw error;
    }

    const existingMembership = await CourseMembershipModel.findOne({
      courseId: course._id,
      studentId,
    });

    if (!existingMembership) {
      throw error;
    }

    return {
      created: false,
      membership: {
        courseId: existingMembership.courseId.toString(),
        studentId: existingMembership.studentId.toString(),
        joinedAt: existingMembership.joinedAt,
      },
    };
  }
}

export async function listCourses(userId: string, role: UserRole, query: ListCoursesQuery) {
  const baseFilter: Record<string, unknown> = role === 'teacher'
    ? { teacherId: userId }
    : {
        _id: {
          $in: (await CourseMembershipModel.find({ studentId: userId }).select('courseId')).map(
            (membership) => membership.courseId,
          ),
        },
      };
  const filter = query.q ? { ...baseFilter, $text: { $search: query.q } } : baseFilter;
  const skip = (query.page - 1) * query.limit;
  let coursesQuery = CourseModel.find(filter)
    .sort({ createdAt: -1 })
    .skip(skip)
    .limit(query.limit);

  if (role === 'teacher') {
    coursesQuery = coursesQuery.select('+joinCode');
  }

  const [courses, total] = await Promise.all([
    coursesQuery,
    CourseModel.countDocuments(filter),
  ]);

  return {
    data: courses.map((course) => ({
      id: course.id,
      name: course.name,
      description: course.description,
      teacherId: course.teacherId.toString(),
      ...(role === 'teacher' ? { joinCode: course.joinCode } : {}),
      createdAt: course.createdAt,
    })),
    meta: { page: query.page, limit: query.limit, total },
  };
}

export async function getCourse(courseId: string, userId: string, role: UserRole) {
  let courseQuery = CourseModel.findById(courseId);
  if (role === 'teacher') {
    courseQuery = courseQuery.select('+joinCode');
  }
  const course = await courseQuery;

  if (!course) {
    throw new AppError(404, 'COURSE_NOT_FOUND', 'Course not found.');
  }

  let canAccess = false;
  if (role === 'teacher') {
    canAccess = course.teacherId.toString() === userId;
  } else {
    canAccess = Boolean(await CourseMembershipModel.exists({ courseId: course._id, studentId: userId }));
  }

  if (!canAccess) {
    throw new AppError(404, 'COURSE_NOT_FOUND', 'Course not found.');
  }

  const result = {
    id: course.id,
    name: course.name,
    description: course.description,
    teacherId: course.teacherId.toString(),
    createdAt: course.createdAt,
  };

  if (role === 'teacher') return { ...result, joinCode: course.joinCode };

  return result;
}
