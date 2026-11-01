package com.yupi.yuojbackendquestionservice.aop;

import com.yupi.yuojbackendcommon.annotation.AuthCheck;
import com.yupi.yuojbackendcommon.common.ErrorCode;
import com.yupi.yuojbackendcommon.constant.UserConstant;
import com.yupi.yuojbackendcommon.exception.BusinessException;
import com.yupi.yuojbackendmodel.model.entity.User;
import org.apache.commons.lang3.StringUtils;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.RequestAttributes;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import javax.servlet.http.HttpServletRequest;

/**
 * 权限校验切面：拦截 @AuthCheck，校验当前登录用户是否具备指定角色
 */
@Aspect
@Component
public class AuthInterceptor {

    @Around("@annotation(authCheck)")
    public Object doInterceptor(ProceedingJoinPoint joinPoint, AuthCheck authCheck) throws Throwable {
        String mustRole = authCheck.mustRole();
        RequestAttributes requestAttributes = RequestContextHolder.currentRequestAttributes();
        HttpServletRequest request = ((ServletRequestAttributes) requestAttributes).getRequest();
        Object userObj = request.getSession().getAttribute(UserConstant.USER_LOGIN_STATE);
        User loginUser = (User) userObj;
        if (loginUser == null) {
            throw new BusinessException(ErrorCode.NOT_LOGIN_ERROR);
        }
        // 注解未指定角色则不校验
        if (StringUtils.isBlank(mustRole)) {
            return joinPoint.proceed();
        }
        String userRole = loginUser.getUserRole();
        // 被封号用户禁止访问
        if (UserConstant.BAN_ROLE.equals(userRole)) {
            throw new BusinessException(ErrorCode.FORBIDDEN_ERROR, "账号已被封禁");
        }
        if (!mustRole.equals(userRole)) {
            throw new BusinessException(ErrorCode.NO_AUTH_ERROR);
        }
        return joinPoint.proceed();
    }
}
