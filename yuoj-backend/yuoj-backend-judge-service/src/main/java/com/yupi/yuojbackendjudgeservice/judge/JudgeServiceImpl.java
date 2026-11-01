package com.yupi.yuojbackendjudgeservice.judge;

import cn.hutool.json.JSONUtil;
import com.yupi.yuojbackendcommon.common.ErrorCode;
import com.yupi.yuojbackendcommon.exception.BusinessException;
import com.yupi.yuojbackendmodel.model.enums.JudgeInfoMessageEnum;
import com.yupi.yuojbackendjudgeservice.judge.codesandbox.CodeSandbox;
import com.yupi.yuojbackendjudgeservice.judge.codesandbox.CodeSandboxFactory;
import com.yupi.yuojbackendjudgeservice.judge.codesandbox.CodeSandboxProxy;
import com.yupi.yuojbackendjudgeservice.judge.strategy.JudgeContext;
import com.yupi.yuojbackendmodel.model.codesandbox.ExecuteCodeRequest;
import com.yupi.yuojbackendmodel.model.codesandbox.ExecuteCodeResponse;
import com.yupi.yuojbackendmodel.model.codesandbox.JudgeInfo;
import com.yupi.yuojbackendmodel.model.dto.question.JudgeCase;
import com.yupi.yuojbackendmodel.model.entity.Question;
import com.yupi.yuojbackendmodel.model.entity.QuestionSubmit;
import com.yupi.yuojbackendmodel.model.enums.QuestionSubmitStatusEnum;
import com.yupi.yuojbackendserviceclient.service.QuestionFeignClient;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.annotation.Resource;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
public class JudgeServiceImpl implements JudgeService {

    @Resource
    private QuestionFeignClient questionFeignClient;

    @Resource
    private JudgeManager judgeManager;

    @Value("${codesandbox.type:example}")
    private String type;


    /**
     * 判题入口：任何异常都必须把提交记录落到「失败」状态，
     * 否则记录会永久停留在「判题中」，用户侧看不到结局。
     *
     * @param questionSubmitId 题目提交 id
     * @return 判题后的提交记录
     */
    @Override
    public QuestionSubmit doJudge(long questionSubmitId) {
        try {
            return doJudgeInternal(questionSubmitId);
        } catch (Exception e) {
            log.error("判题异常, questionSubmitId = {}", questionSubmitId, e);
            // 兜底：把记录置为失败，避免永久停留在「判题中」
            QuestionSubmit failUpdate = new QuestionSubmit();
            failUpdate.setId(questionSubmitId);
            failUpdate.setStatus(QuestionSubmitStatusEnum.FAILED.getValue());
            JudgeInfo judgeInfo = new JudgeInfo();
            judgeInfo.setMessage(JudgeInfoMessageEnum.SYSTEM_ERROR.getValue());
            failUpdate.setJudgeInfo(JSONUtil.toJsonStr(judgeInfo));
            try {
                questionFeignClient.updateQuestionSubmitById(failUpdate);
            } catch (Exception ex) {
                log.error("回写失败状态也失败了, questionSubmitId = {}", questionSubmitId, ex);
            }
            // 仍抛出，由 MQ 消费端决定 ack/nack
            throw e;
        }
    }

    /**
     * 判题主流程
     *
     * @param questionSubmitId 题目提交 id
     * @return 判题后的提交记录
     */
    private QuestionSubmit doJudgeInternal(long questionSubmitId) {
        // 1）传入题目的提交 id，获取到对应的题目、提交信息（包含代码、编程语言等）
        QuestionSubmit questionSubmit = questionFeignClient.getQuestionSubmitById(questionSubmitId);
        if (questionSubmit == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND_ERROR, "提交信息不存在");
        }
        Long questionId = questionSubmit.getQuestionId();
        Question question = questionFeignClient.getQuestionById(questionId);
        if (question == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND_ERROR, "题目不存在");
        }
        // 2）如果题目提交状态不为等待中，就不用重复执行了
        if (!questionSubmit.getStatus().equals(QuestionSubmitStatusEnum.WAITING.getValue())) {
            throw new BusinessException(ErrorCode.OPERATION_ERROR, "题目正在判题中");
        }
        // 3）更改判题（题目提交）的状态为 “判题中”，防止重复执行
        QuestionSubmit questionSubmitUpdate = new QuestionSubmit();
        questionSubmitUpdate.setId(questionSubmitId);
        questionSubmitUpdate.setStatus(QuestionSubmitStatusEnum.RUNNING.getValue());
        boolean update = questionFeignClient.updateQuestionSubmitById(questionSubmitUpdate);
        if (!update) {
            throw new BusinessException(ErrorCode.SYSTEM_ERROR, "题目状态更新错误");
        }
        // 4）调用沙箱，获取到执行结果
        CodeSandbox codeSandbox = CodeSandboxFactory.newInstance(type);
        codeSandbox = new CodeSandboxProxy(codeSandbox);
        String language = questionSubmit.getLanguage();
        String code = questionSubmit.getCode();
        // 获取输入用例
        String judgeCaseStr = question.getJudgeCase();
        List<JudgeCase> judgeCaseList = JSONUtil.toList(judgeCaseStr, JudgeCase.class);
        List<String> inputList = judgeCaseList.stream().map(JudgeCase::getInput).collect(Collectors.toList());
        ExecuteCodeRequest executeCodeRequest = ExecuteCodeRequest.builder()
                .code(code)
                .language(language)
                .inputList(inputList)
                .build();
        ExecuteCodeResponse executeCodeResponse = codeSandbox.executeCode(executeCodeRequest);
        List<String> outputList = executeCodeResponse.getOutputList();
        // 5）根据沙箱的执行结果，设置题目的判题状态和信息
        JudgeContext judgeContext = new JudgeContext();
        judgeContext.setJudgeInfo(executeCodeResponse.getJudgeInfo());
        judgeContext.setInputList(inputList);
        judgeContext.setOutputList(outputList);
        judgeContext.setJudgeCaseList(judgeCaseList);
        judgeContext.setQuestion(question);
        judgeContext.setQuestionSubmit(questionSubmit);
        JudgeInfo judgeInfo = judgeManager.doJudge(judgeContext);
        // 6）修改数据库中的判题结果
        questionSubmitUpdate = new QuestionSubmit();
        questionSubmitUpdate.setId(questionSubmitId);
        questionSubmitUpdate.setStatus(QuestionSubmitStatusEnum.SUCCEED.getValue());
        questionSubmitUpdate.setJudgeInfo(JSONUtil.toJsonStr(judgeInfo));
        update = questionFeignClient.updateQuestionSubmitById(questionSubmitUpdate);
        if (!update) {
            throw new BusinessException(ErrorCode.SYSTEM_ERROR, "题目状态更新错误");
        }
        return questionFeignClient.getQuestionSubmitById(questionSubmitId);
    }
}
